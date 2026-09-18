# RAIS Vínculos — Variable Consistency Across Years

Built from the real header rows of one state file per year (2000, 2001, 2010, 2015, 2025 — see `rais_vinculos_headers_by_year.txt`). Rows are grouped by underlying concept, not literal text match, so the same real-world variable can be tracked even when its column name changed. "—" means the field doesn't exist in that year's file at all.

**How to read the last column:** "Same" means the literal text is identical everywhere it exists. "Differs (2025 only)" is the common case — usually just `" - Código"` tacked on, harmless. Anything flagged **"Differs — real change"** is a genuine wording/structure difference worth double-checking, not just a suffix.

| Variable (concept) | 2000 | 2001 | 2010 | 2015 | 2025 | Consistent? |
|---|---|---|---|---|---|---|
| Bairros SP | Bairros SP | Bairros SP | Bairros SP | Bairros SP | Bairros SP - Código | Differs (2025 only) |
| Bairros Fortaleza | Bairros Fortaleza | Bairros Fortaleza | Bairros Fortaleza | Bairros Fortaleza | Bairros Fortaleza - Código | Differs (2025 only) |
| Bairros RJ | Bairros RJ | Bairros RJ | Bairros RJ | Bairros RJ | Bairros RJ - Código | Differs (2025 only) |
| Causa Afastamento 1 | — | — | Causa Afastamento 1 | Causa Afastamento 1 | Causa Afastamento 1 - Código | Differs — absent before 2010 |
| Causa Afastamento 2 | — | — | Causa Afastamento 2 | Causa Afastamento 2 | Causa Afastamento 2 - Código | Differs — absent before 2010 |
| Causa Afastamento 3 | — | — | Causa Afastamento 3 | Causa Afastamento 3 | Causa Afastamento 3 - Código | Differs — absent before 2010 |
| Motivo Desligamento | Motivo Desligamento | Motivo Desligamento | Motivo Desligamento | Motivo Desligamento | Motivo Desligamento - Código | Differs (2025 only) |
| **Occupation (CBO)** | CBO 94 Ocupação | CBO 94 Ocupação | CBO Ocupação 2002 | CBO Ocupação 2002 | CBO 2002 Ocupação - Código | **Differs — real change** (94 vs 2002 revision, word order flips) |
| **Industry, CNAE 2.0 Classe** | — | — | CNAE 2.0 Classe | CNAE 2.0 Classe | CNAE 2.0 Classe - Código | **Differs — doesn't exist before ~2010** |
| CNAE 95 Classe | CNAE 95 Classe | CNAE 95 Classe | CNAE 95 Classe | CNAE 95 Classe | CNAE 95 Classe - Código | Differs (2025 only) |
| Distritos SP | Distritos SP | Distritos SP | Distritos SP | Distritos SP | Distritos SP - Código | Differs (2025 only) |
| **Active as of Dec 31** | Vínculo Ativo 31/12 | Vínculo Ativo 31/12 | Vínculo Ativo 31/12 | Vínculo Ativo 31/12 | Ind Vínculo Ativo 31/12 - Código | **Differs — real change** (this is the active-employment filter variable, already known to need its own rename) |
| Faixa Etária | Faixa Etária | Faixa Etária | Faixa Etária | Faixa Etária | Faixa Etária - Código | Differs (2025 only) |
| Faixa Hora Contrat | Faixa Hora Contrat | Faixa Hora Contrat | Faixa Hora Contrat | Faixa Hora Contrat | Faixa Hora Contrat - Código | Differs (2025 only) |
| Faixa Remun/Rem Dezembro (SM) | Faixa Remun Dezem (SM) | Faixa Remun Dezem (SM) | Faixa Remun Dezem (SM) | Faixa Remun Dezem (SM) | Faixa Rem Dez (SM) - Código | **Differs — real change** ("Remun Dezem" shortened to "Rem Dez") |
| Faixa Remun/Rem Média (SM) | Faixa Remun Média (SM) | Faixa Remun Média (SM) | Faixa Remun Média (SM) | Faixa Remun Média (SM) | Faixa Rem Média (SM) - Código | Differs (2025 only, "Remun"→"Rem") |
| Faixa Tempo Emprego | Faixa Tempo Emprego | Faixa Tempo Emprego | Faixa Tempo Emprego | Faixa Tempo Emprego | Faixa Tempo Emprego - Código | Differs (2025 only) |
| **Education level** | Grau Instrução 2005-1985 | Grau Instrução 2005-1985 | Escolaridade após 2005 | Escolaridade após 2005 | Escolaridade Após 2005 - Código | **Differs — real change** (completely different field name pre/post ~2010) |
| Qtd Hora Contr | Qtd Hora Contr | Qtd Hora Contr | Qtd Hora Contr | Qtd Hora Contr | Qtd Hora Contr | **Same across all 5 years** |
| Idade (age) | Idade | Idade | Idade | Idade | Idade | **Same across all 5 years** |
| Ind CEI Vinculado | Ind CEI Vinculado | Ind CEI Vinculado | Ind CEI Vinculado | Ind CEI Vinculado | Ind CEI Vinculado - Código | Differs (2025 only) |
| **Simples participant** | — | Ind Simples | Ind Simples | Ind Simples | Ind Estabelecimento Participante SIMPLES - Código | **Differs — absent in 2000, renamed by 2025** |
| Mês Admissão | Mês Admissão | Mês Admissão | Mês Admissão | Mês Admissão | Mês Admissão - Código | Differs (2025 only) |
| Mês Desligamento | Mês Desligamento | Mês Desligamento | Mês Desligamento | Mês Desligamento | Mês Desligamento - Código | Differs (2025 only) |
| **Work municipality (Mun Trab)** | — | — | Mun Trab | Mun Trab | Município Trab - Código | Differs — absent before 2010, spelled out by 2025 |
| **Municipality (the one we use)** | Município | Município | Município | Município | Município - Código | Differs (2025 only) |
| Nacionalidade | Nacionalidade | Nacionalidade | Nacionalidade | Nacionalidade | Nacionalidade - Código | Differs (2025 only) |
| Natureza Jurídica (legal nature) | Natureza Jurídica | Natureza Jurídica | Natureza Jurídica | Natureza Jurídica | Natureza Jurídica - Código | Differs (2025 only) |
| Ind Portador Defic | — | — | Ind Portador Defic | Ind Portador Defic | Ind Portador Defic - Código | Differs — absent before 2010 |
| Qtd Dias Afastamento | — | — | Qtd Dias Afastamento | Qtd Dias Afastamento | Qtd Dias Afastamento | Differs — absent before 2010, identical 2010-2025 |
| Raça Cor (race) | — | — | Raça Cor | Raça Cor | Raça Cor - Código | Differs — absent before 2010 |
| Regiões/Região Adm DF | Regiões Adm DF | Regiões Adm DF | Regiões Adm DF | Regiões Adm DF | Região Adm DF - Código | Differs (2025: plural→singular + suffix) |
| Vl Remun/Rem Dezembro Nom | Vl Remun Dezembro Nom | Vl Remun Dezembro Nom | Vl Remun Dezembro Nom | Vl Remun Dezembro Nom | Vl Rem Dezembro Nom | Differs (2025: "Remun"→"Rem", no suffix here) |
| Vl Remun/Rem Dezembro (SM) | Vl Remun Dezembro (SM) | Vl Remun Dezembro (SM) | Vl Remun Dezembro (SM) | Vl Remun Dezembro (SM) | Vl Rem Dezembro (SM) | Differs (2025 only, "Remun"→"Rem") |
| Vl Remun/Rem Média Nom | Vl Remun Média Nom | Vl Remun Média Nom | Vl Remun Média Nom | Vl Remun Média Nom | Vl Rem Média Nom | Differs (2025 only, "Remun"→"Rem") |
| Vl Remun/Rem Média (SM) | Vl Remun Média (SM) | Vl Remun Média (SM) | Vl Remun Média (SM) | Vl Remun Média (SM) | Vl Rem Média (SM) | Differs (2025 only, "Remun"→"Rem") |
| Industry, CNAE 2.0 Subclasse | — | — | CNAE 2.0 Subclasse | CNAE 2.0 Subclasse | CNAE 2.0 Subclasse - **Codigo** (no accent - typo in source) | Differs — absent before 2010; note 2025's own inconsistent accent |
| Sexo (sex) | Sexo Trabalhador | Sexo Trabalhador | Sexo Trabalhador | Sexo Trabalhador | Sexo - Código | Differs (2025 drops "Trabalhador") |
| Tamanho Estabelecimento | Tamanho Estabelecimento | Tamanho Estabelecimento | Tamanho Estabelecimento | Tamanho Estabelecimento | Tamanho Estabelecimento - Código | Differs (2025 only) |
| Tempo Emprego (job tenure) | Tempo Emprego | Tempo Emprego | Tempo Emprego | Tempo Emprego | Tempo Emprego | **Same across all 5 years** |
| Tipo Admissão | Tipo Admissão | Tipo Admissão | Tipo Admissão | Tipo Admissão | Tipo Admissão Trabalhador - Código | Differs (2025 adds "Trabalhador") |
| **Tipo Estab — code (1st occurrence)** | Tipo Estab | Tipo Estab | Tipo Estab | Tipo Estab | Tipo Estabelecimento - Código | Differs (2025 spells it out, and finally distinguishes it from the name version below) |
| **Tipo Estab — name, e.g. "CNPJ" (2nd occurrence)** | Tipo Estab | Tipo Estab | Tipo Estab | Tipo Estab | Tipo Estabelecimento - Nome | Same issue as above — 2000-2015 literally duplicate the header text, only distinguishable by position (confirmed against real data, see clean_rais_hpc.do notes) |
| Tipo Defic | — | — | Tipo Defic | Tipo Defic | Tipo Deficiência - Código | Differs — absent before 2010, spelled out by 2025 |
| Tipo Vínculo | Tipo Vínculo | Tipo Vínculo | Tipo Vínculo | Tipo Vínculo | Tipo Vínculo - Código | Differs (2025 only) |
| IBGE Subsetor | — | — | — | IBGE Subsetor | IBGE Subsetor - Código | Differs — only appears starting 2015 |
| **Monthly wages, Jan-Nov (11 fields)** | — | — | — | Vl Rem \<Month\> **CC** | Vl Rem \<Month\> **SC** | **Differs — only exist from 2015 on, and the suffix changed from CC to SC by 2025 (worth checking what CC/SC actually stand for before assuming they're the same thing)** |
| Ano Chegada Brasil | — | — | — | — | Ano Chegada Brasil | New in 2025 only |
| Ind Trabalho Intermitente | — | — | — | — | Ind Trabalho Intermitente - Código | New in 2025 only |
| Ind Trabalho Parcial | — | — | — | — | Ind Trabalho Parcial - Código | New in 2025 only |
| Ind Vínculo Abandonado | — | — | — | — | Ind Vínculo Abandonado - Código | New in 2025 only |
| Categoria Trabalhador | — | — | — | — | Categoria Trabalhador - Código | New in 2025 only |

## The short version

- **Fields that never change, ever**: `Qtd Hora Contr`, `Idade`, `Tempo Emprego`. Nothing to worry about there.
- **Fields where 2025 just tacks on `" - Código"` (or drops "Remun"→"Rem")**: the large majority of the table. Cosmetic, already handled by the `capture rename` fallbacks in `clean_rais_hpc.do`.
- **Fields that genuinely don't exist before ~2010**: CNAE 2.0 Classe/Subclasse, Causa Afastamento 1-3, Ind Portador Defic, Raça Cor, Qtd Dias Afastamento, Tipo Defic. This is the real reason the cleaning file can't reach back before ~2010 without dropping variables.
- **Fields that only exist from 2015 on**: IBGE Subsetor, and all 11 monthly wage columns. So even within the "2010 onward" window you're now targeting, 2010 itself is missing the monthly wage breakdown — only Dezembro/Média survive that far back.
- **Genuinely different wording, not just a suffix**: Occupation (CBO 94 vs CBO 2002), Education (`Grau Instrução 2005-1985` vs `Escolaridade após 2005`), the active-employment flag, and the wage-bracket field naming. These are the ones actually worth double-checking by hand if you ever run this on a year other than what's already verified.
