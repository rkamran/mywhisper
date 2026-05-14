using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MyWhisper.Services;

public sealed record PolisherConfig(string Endpoint, string Model, string ApiKey, TimeSpan Timeout);

/// <summary>
/// Sends a raw Whisper transcript to an OpenAI-compatible chat-completions
/// endpoint (Ollama Cloud by default) and returns the cleaned-up text.
///
/// The system prompt below is the single source of truth at
/// <c>shared/polish-prompt.md</c> — keep them in sync.
/// </summary>
public static class Polisher
{
    private const string SystemPrompt =
        """
        You are a dictation cleanup assistant. The user dictates text into any app; your job is to return the SAME content rewritten with correct punctuation, capitalization, and natural formatting.

        Rules:
        - Preserve meaning exactly. Do NOT add facts, opinions, commentary, headings, or words the speaker did not say.
        - Fix punctuation, capitalization, and obvious filler ("um", "uh", repeated stutters).

        Formatting heuristics — apply only when the speaker clearly signals structure:
        - Numbered enumeration ("number one… number two… number three…" / "first… second… third… finally…" / "step one… step two…") → numbered markdown list (1. 2. 3.) with the introductory sentence kept as a lead-in ending in a colon. Drop the literal "number one"/"first" tokens.
        - Comma-separated set following a list-introducing phrase ("buy groceries: milk, tea, and bananas" / "the agenda is X, Y, and Z") → bulleted markdown list (- one per line). Drop the trailing "and".
        - "New line" → single line break; "new paragraph" → blank line. Drop the literal phrase.
        - Spoken punctuation ("comma", "period", "question mark", "colon", "exclamation point") → insert that punctuation, drop the word.

        Do NOT format as a list if the speaker only used commas without a list-introducing phrase, or if there are fewer than two items.

        Output ONLY the cleaned text. No preamble, no explanation, no surrounding quotes, no trailing newline.
        """;

    /// <summary>
    /// Returns the polished transcript. Throws on HTTP/timeout/parse failure;
    /// the caller is expected to fall back to the raw transcript.
    /// </summary>
    public static async Task<string> PolishAsync(string raw, PolisherConfig config, CancellationToken ct = default)
    {
        using var http = new HttpClient { Timeout = config.Timeout };
        http.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", config.ApiKey);

        var requestBody = new ChatRequest(
            Model: config.Model,
            Stream: false,
            Temperature: 0.2,
            Messages: new[]
            {
                new ChatMessage("system", SystemPrompt),
                new ChatMessage("user", raw)
            });

        using var response = await http.PostAsJsonAsync(config.Endpoint, requestBody, ct);
        if (!response.IsSuccessStatusCode)
        {
            string body = await response.Content.ReadAsStringAsync(ct);
            string snippet = body.Length > 200 ? body[..200] : body;
            throw new HttpRequestException($"HTTP {(int)response.StatusCode}: {snippet}");
        }

        var parsed = await response.Content.ReadFromJsonAsync<ChatResponse>(cancellationToken: ct);
        string? content = parsed?.Choices?.FirstOrDefault()?.Message?.Content;
        if (string.IsNullOrWhiteSpace(content))
            throw new JsonException("Response contained no message content.");

        return content.Trim();
    }

    // ── OpenAI-compatible chat-completions DTOs ─────────────────────────────

    private sealed record ChatRequest(
        [property: JsonPropertyName("model")] string Model,
        [property: JsonPropertyName("stream")] bool Stream,
        [property: JsonPropertyName("temperature")] double Temperature,
        [property: JsonPropertyName("messages")] ChatMessage[] Messages);

    private sealed record ChatMessage(
        [property: JsonPropertyName("role")] string Role,
        [property: JsonPropertyName("content")] string Content);

    private sealed record ChatResponse(
        [property: JsonPropertyName("choices")] ChatChoice[]? Choices);

    private sealed record ChatChoice(
        [property: JsonPropertyName("message")] ChatMessage? Message);
}
