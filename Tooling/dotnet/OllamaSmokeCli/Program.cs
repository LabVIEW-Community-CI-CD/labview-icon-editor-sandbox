using System.Diagnostics;
using System.Linq;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Security.Cryptography;

internal static class Program
{
    private const int ExitSuccess = 0;
    private const int ExitUnexpected = 1;
    private const int ExitHttpError = 2;
    private const int ExitTimeout = 3;
    private const int ExitModelMissing = 4;

    private sealed record Options(
        string Endpoint,
        string Model,
        string Prompt,
        int TimeoutSec,
        bool Stream,
        string Mode,
        string Format,
        bool CheckModel,
        int Retries,
        int RetryDelayMs,
        bool Verbose,
        string? SaveBodyPath);

    private static int Main(string[] args)
    {
        try
        {
            var opts = Parse(args);
            return RunAsync(opts).GetAwaiter().GetResult();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"error: {ex.Message}");
            return ExitUnexpected;
        }
    }

    private static async Task<int> RunAsync(Options opts)
    {
        var sw = Stopwatch.StartNew();
        var baseUri = opts.Endpoint.EndsWith("/") ? opts.Endpoint : $"{opts.Endpoint}/";
        var path = opts.Mode.Equals("chat", StringComparison.OrdinalIgnoreCase)
            ? "api/chat"
            : opts.Mode.Equals("embed", StringComparison.OrdinalIgnoreCase)
                ? "api/embed"
                : "api/generate";
        var uri = new Uri(new Uri(baseUri), path);

        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(opts.TimeoutSec > 0 ? opts.TimeoutSec : 30) };

        if (opts.CheckModel && !await EnsureModelAsync(client, baseUri, opts.Model))
        {
            return ExitModelMissing;
        }

        var payload = opts.Mode.Equals("chat", StringComparison.OrdinalIgnoreCase)
            ? JsonSerializer.Serialize(new
            {
                model = opts.Model,
                messages = new[] { new { role = "user", content = opts.Prompt } },
                stream = opts.Stream
            })
            : opts.Mode.Equals("embed", StringComparison.OrdinalIgnoreCase)
                ? JsonSerializer.Serialize(new { model = opts.Model, input = opts.Prompt })
                : JsonSerializer.Serialize(new { model = opts.Model, prompt = opts.Prompt, stream = opts.Stream });
        var payloadString = payload;

        if (opts.Verbose)
        {
            Console.WriteLine($"[verbose] POST {uri} mode={opts.Mode} stream={opts.Stream} retries={opts.Retries} retryDelayMs={opts.RetryDelayMs}");
            Console.WriteLine($"[verbose] payload: {payloadString}");
        }

        if (opts.Mode.Equals("embed", StringComparison.OrdinalIgnoreCase))
        {
            return await RunEmbedAsync(client, uri, payloadString, opts, sw);
        }

        if (opts.Stream)
        {
            return await RunStreamAsync(client, uri, payloadString, opts, sw);
        }

        var (response, timedOut) = await SendWithRetry(client, () => BuildPost(uri, payloadString), stream: false, opts.Retries, opts.RetryDelayMs);
        if (timedOut)
        {
            Console.Error.WriteLine("fail: request timed out");
            return ExitTimeout;
        }
        if (response == null)
        {
            Console.Error.WriteLine("fail: no response received");
            return ExitUnexpected;
        }

        var body = await response.Content.ReadAsStringAsync();
        if (!string.IsNullOrWhiteSpace(opts.SaveBodyPath))
        {
            File.WriteAllText(opts.SaveBodyPath, body);
        }
        var elapsed = sw.ElapsedMilliseconds;

        if (!response.IsSuccessStatusCode)
        {
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            if (!opts.Verbose)
            {
                Console.Error.WriteLine(body);
            }
            return ExitHttpError;
        }

        var text = ExtractResponseText(body);
        if (opts.Format.Equals("text", StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine(text);
            return ExitSuccess;
        }

        var output = new
        {
            endpoint = uri.ToString(),
            model = opts.Model,
            prompt = opts.Prompt,
            mode = opts.Mode,
            stream = opts.Stream,
            elapsedMs = elapsed,
            response = text
        };

        Console.WriteLine(JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true }));
        return ExitSuccess;
    }

    private static async Task<int> RunEmbedAsync(HttpClient client, Uri uri, string payload, Options opts, Stopwatch sw)
    {
        var (response, timedOut) = await SendWithRetry(client, () => BuildPost(uri, payload), stream: false, opts.Retries, opts.RetryDelayMs);
        if (timedOut)
        {
            Console.Error.WriteLine("fail: request timed out");
            return ExitTimeout;
        }
        if (response == null)
        {
            Console.Error.WriteLine("fail: no response received");
            return ExitUnexpected;
        }

        var body = await response.Content.ReadAsStringAsync();
        if (!string.IsNullOrWhiteSpace(opts.SaveBodyPath))
        {
            File.WriteAllText(opts.SaveBodyPath, body);
        }
        var elapsed = sw.ElapsedMilliseconds;

        if (!response.IsSuccessStatusCode)
        {
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            if (!opts.Verbose)
            {
                Console.Error.WriteLine(body);
            }
            return ExitHttpError;
        }

        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            var vec = ExtractEmbedding(root);
            if (vec == null || vec.Length == 0)
            {
                Console.Error.WriteLine("fail: embed response missing embedding data");
                Console.Error.WriteLine(body);
                return ExitUnexpected;
            }

            var hash = Sha256String(string.Join(",", vec.Select(v => v.ToString("G17"))));
            if (opts.Format.Equals("text", StringComparison.OrdinalIgnoreCase))
            {
                Console.WriteLine($"len={vec.Length} sha256={hash}");
                return ExitSuccess;
            }

            var output = new
            {
                endpoint = uri.ToString(),
                model = opts.Model,
                prompt = opts.Prompt,
                mode = opts.Mode,
                elapsedMs = elapsed,
                length = vec.Length,
                sha256 = hash
            };
            Console.WriteLine(JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true }));
            return ExitSuccess;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"fail: embed parse error: {ex.Message}");
            Console.Error.WriteLine(body);
            return ExitUnexpected;
        }
    }

    private static async Task<int> RunStreamAsync(HttpClient client, Uri uri, string payload, Options opts, Stopwatch sw)
    {
        var (response, timedOut) = await SendWithRetry(client, () => BuildPost(uri, payload), stream: true, opts.Retries, opts.RetryDelayMs);
        if (timedOut)
        {
            Console.Error.WriteLine("fail: request timed out");
            return ExitTimeout;
        }
        if (response == null)
        {
            Console.Error.WriteLine("fail: no response received");
            return ExitUnexpected;
        }
        if (!response.IsSuccessStatusCode)
        {
            var errBody = await response.Content.ReadAsStringAsync();
            if (!string.IsNullOrWhiteSpace(opts.SaveBodyPath))
            {
                File.WriteAllText(opts.SaveBodyPath, errBody);
            }
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            if (!opts.Verbose)
            {
                Console.Error.WriteLine(errBody);
            }
            return ExitHttpError;
        }

        var sb = new StringBuilder();
        await using var stream = await response.Content.ReadAsStreamAsync();
        using var reader = new StreamReader(stream);

        while (!reader.EndOfStream)
        {
            var line = await reader.ReadLineAsync();
            if (string.IsNullOrWhiteSpace(line)) { continue; }
            try
            {
                using var doc = JsonDocument.Parse(line);
                var chunk = ExtractResponseText(doc.RootElement);
                if (!string.IsNullOrEmpty(chunk))
                {
                    sb.Append(chunk);
                    Console.Write(chunk);
                }
                if (doc.RootElement.TryGetProperty("done", out var doneProp) && doneProp.ValueKind == JsonValueKind.True)
                {
                    break;
                }
            }
            catch
            {
                // fall back to raw line
                sb.Append(line);
                Console.Write(line);
            }
        }

        var elapsed = sw.ElapsedMilliseconds;
        Console.WriteLine(); // end streamed tokens
        if (opts.Format.Equals("text", StringComparison.OrdinalIgnoreCase))
        {
            return 0;
        }

        var output = new
        {
            endpoint = uri.ToString(),
            model = opts.Model,
            prompt = opts.Prompt,
            mode = opts.Mode,
            stream = true,
            elapsedMs = elapsed,
            response = sb.ToString()
        };
        Console.WriteLine(JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true }));
        return 0;
    }

    private static HttpRequestMessage BuildPost(Uri uri, string payload)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, uri);
        request.Content = new StringContent(payload, Encoding.UTF8, "application/json");
        return request;
    }

    private static async Task<(HttpResponseMessage? Response, bool Timeout)> SendWithRetry(
        HttpClient client,
        Func<HttpRequestMessage> requestFactory,
        bool stream,
        int retries,
        int retryDelayMs)
    {
        HttpResponseMessage? resp = null;
        for (var attempt = 0; attempt <= retries; attempt++)
        {
            resp?.Dispose();
            var req = requestFactory();
            try
            {
                resp = await client.SendAsync(req, stream ? HttpCompletionOption.ResponseHeadersRead : HttpCompletionOption.ResponseContentRead);
                if ((int)resp.StatusCode >= 500 && attempt < retries)
                {
                    await Task.Delay(Math.Max(0, retryDelayMs));
                    continue;
                }
                return (resp, false);
            }
            catch (TaskCanceledException)
            {
                if (attempt < retries)
                {
                    await Task.Delay(Math.Max(0, retryDelayMs));
                    continue;
                }
                return (null, true);
            }
            catch
            {
                if (attempt < retries)
                {
                    await Task.Delay(Math.Max(0, retryDelayMs));
                    continue;
                }
                throw;
            }
        }

        return (resp, false);
    }

    private static string ExtractResponseText(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            return ExtractResponseText(doc.RootElement);
        }
        catch
        {
            return body;
        }
    }

    private static string ExtractResponseText(JsonElement root)
    {
        if (root.ValueKind == JsonValueKind.Object)
        {
            if (root.TryGetProperty("response", out var resp) && resp.ValueKind == JsonValueKind.String)
            {
                return resp.GetString() ?? string.Empty;
            }
            if (root.TryGetProperty("message", out var msg) && msg.ValueKind == JsonValueKind.Object &&
                msg.TryGetProperty("content", out var content) && content.ValueKind == JsonValueKind.String)
            {
                return content.GetString() ?? string.Empty;
            }
        }
        return string.Empty;
    }

    private static async Task<bool> EnsureModelAsync(HttpClient client, string baseUri, string model)
    {
        var uri = new Uri(new Uri(baseUri), "api/tags");
        try
        {
            var response = await client.GetAsync(uri);
            if (!response.IsSuccessStatusCode)
            {
                Console.Error.WriteLine($"fail: model check status={(int)response.StatusCode} reason={response.ReasonPhrase}");
                return false;
            }
            var body = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("models", out var models) && models.ValueKind == JsonValueKind.Array)
            {
                foreach (var m in models.EnumerateArray())
                {
                    var name = m.TryGetProperty("name", out var n) ? n.GetString() : null;
                    var modelField = m.TryGetProperty("model", out var mf) ? mf.GetString() : null;
                    if (string.Equals(name, model, StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(modelField, model, StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(name, $"{model}:latest", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(modelField, $"{model}:latest", StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }
            }
            Console.Error.WriteLine($"fail: model '{model}' not found in tags");
            return false;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"fail: model check error: {ex.Message}");
            return false;
        }
    }

    private static double[]? ExtractEmbedding(JsonElement root)
    {
        if (root.ValueKind != JsonValueKind.Object) return null;
        if (root.TryGetProperty("embedding", out var emb) && emb.ValueKind == JsonValueKind.Array)
        {
            return emb.EnumerateArray().Select(e => e.GetDouble()).ToArray();
        }
        if (root.TryGetProperty("embeddings", out var embs) && embs.ValueKind == JsonValueKind.Array)
        {
            var first = embs.EnumerateArray().FirstOrDefault();
            if (first.ValueKind == JsonValueKind.Array)
            {
                return first.EnumerateArray().Select(e => e.GetDouble()).ToArray();
            }
        }
        return null;
    }

    private static string Sha256String(string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        var hash = SHA256.HashData(bytes);
        return BitConverter.ToString(hash).Replace("-", string.Empty).ToLowerInvariant();
    }

    private static Options Parse(string[] args)
    {
        var endpoint = "http://localhost:11435";
        var model = "llama3-8b-local";
        var prompt = "Hello smoke";
        var timeoutSec = 30;
        var stream = false;
        var mode = "generate";
        var format = "json";
        var checkModel = false;
        var retries = 0;
        var retryDelayMs = 1000;
        var verbose = false;
        string? saveBodyPath = null;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            switch (arg)
            {
                case "-e":
                case "--endpoint":
                    endpoint = Next(args, ref i, arg);
                    break;
                case "-m":
                case "--model":
                    model = Next(args, ref i, arg);
                    break;
                case "-p":
                case "--prompt":
                    prompt = Next(args, ref i, arg);
                    break;
                case "-t":
                case "--timeout-sec":
                    var raw = Next(args, ref i, arg);
                    if (!int.TryParse(raw, out timeoutSec) || timeoutSec <= 0)
                    {
                        throw new ArgumentException($"Invalid timeout: {raw}");
                    }
                    break;
                case "--stream":
                    stream = true;
                    break;
                case "--chat":
                    mode = "chat";
                    break;
                case "--format":
                    format = Next(args, ref i, arg);
                    if (!format.Equals("json", StringComparison.OrdinalIgnoreCase) && !format.Equals("text", StringComparison.OrdinalIgnoreCase))
                    {
                        throw new ArgumentException($"Invalid format: {format} (expected json|text)");
                    }
                    break;
                case "--embed":
                    mode = "embed";
                    break;
                case "--check-model":
                    checkModel = true;
                    break;
                case "--retries":
                    var rawRetries = Next(args, ref i, arg);
                    if (!int.TryParse(rawRetries, out retries) || retries < 0)
                    {
                        throw new ArgumentException($"Invalid retries: {rawRetries}");
                    }
                    break;
                case "--retry-delay-ms":
                    var rawDelay = Next(args, ref i, arg);
                    if (!int.TryParse(rawDelay, out retryDelayMs) || retryDelayMs < 0)
                    {
                        throw new ArgumentException($"Invalid retry delay: {rawDelay}");
                    }
                    break;
                case "--verbose":
                    verbose = true;
                    break;
                case "--save-body":
                    saveBodyPath = Next(args, ref i, arg);
                    break;
                case "-h":
                case "--help":
                    PrintUsage();
                    Environment.Exit(0);
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: {arg}");
            }
        }

        return new Options(endpoint, model, prompt, timeoutSec, stream, mode, format, checkModel, retries, retryDelayMs, verbose, saveBodyPath);
    }

    private static string Next(string[] args, ref int index, string name)
    {
        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"Missing value for {name}");
        }
        index++;
        return args[index];
    }

    private static void PrintUsage()
    {
        Console.WriteLine("OllamaSmokeCli");
        Console.WriteLine("Usage:");
        Console.WriteLine("  OllamaSmokeCli --endpoint <url> --model <name> --prompt <text> [--chat|--embed] [--timeout-sec 30] [--stream] [--format json|text] [--check-model] [--retries N] [--retry-delay-ms 1000] [--verbose] [--save-body <path>]");
        Console.WriteLine("Defaults: endpoint http://localhost:11435, model llama3-8b-local, prompt \"Hello smoke\", timeout 30s, mode generate, stream false, format json, retries 0, retry delay 1000ms, verbose off.");
    }
}
