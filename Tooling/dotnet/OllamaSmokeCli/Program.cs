using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;

internal static class Program
{
    private sealed record Options(string Endpoint, string Model, string Prompt, int TimeoutSec, bool Stream);

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
        var uri = new Uri(new Uri(baseUri), "api/generate");

        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(opts.TimeoutSec > 0 ? opts.TimeoutSec : 30) };
        var payload = JsonSerializer.Serialize(new { model = opts.Model, prompt = opts.Prompt, stream = opts.Stream });
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
        var output = new
        {
            endpoint = uri.ToString(),
            model = opts.Model,
            prompt = opts.Prompt,
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
                if (doc.RootElement.TryGetProperty("response", out var node) && node.ValueKind == JsonValueKind.String)
                {
                    var chunk = node.GetString() ?? string.Empty;
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
        var output = new
        {
            endpoint = uri.ToString(),
            model = opts.Model,
            prompt = opts.Prompt,
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
            if (doc.RootElement.TryGetProperty("response", out var node) && node.ValueKind == JsonValueKind.String)
            {
                return node.GetString() ?? string.Empty;
            }
        }
        catch
        {
            // fall through to raw body
        }
        return body;
    }

    private static Options Parse(string[] args)
    {
        var endpoint = "http://localhost:11435";
        var model = "llama3-8b-local";
        var prompt = "Hello smoke";
        var timeoutSec = 30;
        var stream = false;

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
                case "-h":
                case "--help":
                    PrintUsage();
                    Environment.Exit(0);
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: {arg}");
            }
        }

        return new Options(endpoint, model, prompt, timeoutSec, stream);
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
        Console.WriteLine("  OllamaSmokeCli --endpoint <url> --model <name> --prompt <text> [--timeout-sec 30] [--stream]");
        Console.WriteLine("Defaults: endpoint http://localhost:11435, model llama3-8b-local, prompt \"Hello smoke\", timeout 30s, stream false.");
    }
}
