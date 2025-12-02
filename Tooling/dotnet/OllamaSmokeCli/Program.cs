using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;

internal static class Program
{
    private sealed record Options(string Endpoint, string Model, string Prompt, int TimeoutSec, bool Stream, string Mode, string Format);

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
            return 1;
        }
    }

    private static async Task<int> RunAsync(Options opts)
    {
        var sw = Stopwatch.StartNew();
        var baseUri = opts.Endpoint.EndsWith("/") ? opts.Endpoint : $"{opts.Endpoint}/";
        var path = opts.Mode.Equals("chat", StringComparison.OrdinalIgnoreCase) ? "api/chat" : "api/generate";
        var uri = new Uri(new Uri(baseUri), path);

        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(opts.TimeoutSec > 0 ? opts.TimeoutSec : 30) };
        var payload = opts.Mode.Equals("chat", StringComparison.OrdinalIgnoreCase)
            ? JsonSerializer.Serialize(new
            {
                model = opts.Model,
                messages = new[] { new { role = "user", content = opts.Prompt } },
                stream = opts.Stream
            })
            : JsonSerializer.Serialize(new { model = opts.Model, prompt = opts.Prompt, stream = opts.Stream });
        using var content = new StringContent(payload, Encoding.UTF8, "application/json");

        if (opts.Stream)
        {
            return await RunStreamAsync(client, uri, content, opts, sw);
        }

        var response = await client.PostAsync(uri, content);
        var body = await response.Content.ReadAsStringAsync();
        var elapsed = sw.ElapsedMilliseconds;

        if (!response.IsSuccessStatusCode)
        {
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            Console.Error.WriteLine(body);
            return 1;
        }

        var text = ExtractResponseText(body);
        if (opts.Format.Equals("text", StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine(text);
            return 0;
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
        return 0;
    }

    private static async Task<int> RunStreamAsync(HttpClient client, Uri uri, HttpContent content, Options opts, Stopwatch sw)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, uri) { Content = content };
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
        if (!response.IsSuccessStatusCode)
        {
            var errBody = await response.Content.ReadAsStringAsync();
            Console.Error.WriteLine($"fail: status={(int)response.StatusCode} reason={response.ReasonPhrase}");
            Console.Error.WriteLine(errBody);
            return 1;
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

    private static Options Parse(string[] args)
    {
        var endpoint = "http://localhost:11435";
        var model = "llama3-8b-local";
        var prompt = "Hello smoke";
        var timeoutSec = 30;
        var stream = false;
        var mode = "generate";
        var format = "json";

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
                case "-h":
                case "--help":
                    PrintUsage();
                    Environment.Exit(0);
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: {arg}");
            }
        }

        return new Options(endpoint, model, prompt, timeoutSec, stream, mode, format);
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
        Console.WriteLine("  OllamaSmokeCli --endpoint <url> --model <name> --prompt <text> [--chat] [--timeout-sec 30] [--stream] [--format json|text]");
        Console.WriteLine("Defaults: endpoint http://localhost:11435, model llama3-8b-local, prompt \"Hello smoke\", timeout 30s, generate mode, stream false, format json.");
    }
}
