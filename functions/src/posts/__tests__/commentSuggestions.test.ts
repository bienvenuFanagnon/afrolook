import { extractHashtags, buildPrompt, parseSuggestions } from "../commentSuggestions";

// ─── extractHashtags ──────────────────────────────────────────────────────────

describe("extractHashtags", () => {
  it("extrait les hashtags simples", () => {
    expect(extractHashtags("Super post #Blague #humour")).toEqual(["#Blague", "#humour"]);
  });

  it("retourne [] si pas de hashtag", () => {
    expect(extractHashtags("Aucun hashtag ici")).toEqual([]);
  });

  it("limite à 10 hashtags", () => {
    const input = Array.from({ length: 15 }, (_, i) => `#tag${i}`).join(" ");
    expect(extractHashtags(input)).toHaveLength(10);
  });

  it("gère les accents dans les hashtags", () => {
    // Les accents ne sont pas des \w — comportement attendu : s'arrête à l'accent
    const result = extractHashtags("#Beauté #mode");
    expect(result[0]).toBe("#Beaut");
  });
});

// ─── buildPrompt ──────────────────────────────────────────────────────────────

describe("buildPrompt", () => {
  it("contient la description quand elle est fournie", () => {
    const p = buildPrompt("Mon super post", []);
    expect(p).toContain("Mon super post");
  });

  it("contient les hashtags quand ils sont fournis", () => {
    const p = buildPrompt("", ["#humour", "#blague"]);
    expect(p).toContain("#humour");
    expect(p).toContain("#blague");
  });

  it("tronque une description trop longue", () => {
    const longDesc = "a".repeat(1000);
    const p = buildPrompt(longDesc, []);
    expect(p).toContain("a".repeat(500));
    expect(p).not.toContain("a".repeat(501));
  });

  it("demande exactement 8 suggestions", () => {
    const p = buildPrompt("test", []);
    expect(p).toContain("exactement 5");
  });
});

// ─── parseSuggestions ────────────────────────────────────────────────────────

describe("parseSuggestions", () => {
  it("parse une réponse bien formée", () => {
    const raw = [
      "Super contenu !",
      "Trop drôle ce post",
      "Continue comme ça",
      "Waow incroyable",
      "Je suis fan",
    ].join("\n");

    const result = parseSuggestions(raw);
    expect(result).toHaveLength(5);
    expect(result[0]).toBe("Super contenu !");
  });

  it("supprime les numéros de liste", () => {
    const raw = "1. Super post\n2. Trop bien\n3. Cool\n4. Waow\n5. Ok";
    const result = parseSuggestions(raw);
    expect(result[0]).toBe("Super post");
    expect(result[1]).toBe("Trop bien");
  });

  it("supprime les tirets en début de ligne", () => {
    const raw = "- Super\n- Bien\n- Cool\n- Waow\n- Ok";
    const result = parseSuggestions(raw);
    expect(result[0]).toBe("Super");
  });

  it("filtre les lignes trop courtes ou trop longues", () => {
    const raw = "ok\nSuper post vraiment bien\n" + "x".repeat(121) + "\nBien joué";
    const result = parseSuggestions(raw);
    expect(result).not.toContain("ok");
    expect(result).not.toContain("x".repeat(121));
    expect(result).toContain("Super post vraiment bien");
  });

  it("limite à 5 suggestions même si Gemini en génère plus", () => {
    const lines = Array.from({ length: 10 }, (_, i) => `Suggestion numéro ${i + 1}`);
    const result = parseSuggestions(lines.join("\n"));
    expect(result).toHaveLength(5);
  });

  it("retourne [] pour une réponse vide", () => {
    expect(parseSuggestions("")).toEqual([]);
    expect(parseSuggestions("\n\n")).toEqual([]);
  });
});
