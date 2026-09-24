* ==========================================================================
* Clean CFEM: build one dataset with one row per royalty payment record
* (process x month).
*
* Takes the raw CSV pulled by /1. Pull Raw Data/CFEM/pull_cfem.py and
* turns it into a Stata dataset with clear English variable names, joinable
* back to SIGMINE via process_number + process_year.
*
* Input:
*   Data/CFEM/Arrecadacao/CFEM_Arrecadacao.csv
*
* Output:
*   Working/Mines/CFEM/cfem_process_month.dta
*
* BEFORE running this file, run Code/config.do once in your Stata session.
*
* File Organization:
*
*		Section 1: Import raw data & rename variables of interest
*		Section 2: Clean up the numeric fields
*		Section 3: Save
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

local CFEM_RAW     "$RAW_DIR/CFEM"
local CFEM_WORKING "$WORKING_DIR/Mines/CFEM"

capture mkdir "$WORKING_DIR/Mines"
capture mkdir "`CFEM_WORKING'"

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Import raw data & rename variables of interest ***********
**********															 ***********
********************************************************************************
********************************************************************************

* encoding("windows-1252") because this file uses the same accented-
* character encoding as SIGMINE/SCM, not UTF-8 - if Portuguese text comes
* out garbled below, this is the first thing to check.
import delimited using "`CFEM_RAW'/Arrecadacao/CFEM_Arrecadacao.csv", ///
    clear varnames(1) encoding("windows-1252")


rename (ano mês processo anodoprocesso tipo_pf_pj cpf_cnpj uf codigomunicipio ///
        quantidadecomercializada unidadedemedida valorrecolhido datacriacao substância município) ///
       (year month process_number process_year payer_type taxpayer_id state municipality_code ///
        quantity_sold unit_of_measure royalty_value record_created_at substance municipality_name)
		
********************************************************************************
********************************************************************************
**********															 ***********
********** 			Section 2: Clean up the numeric fields           ***********
**********															 ***********
********************************************************************************
********************************************************************************

* quantity_sold and royalty_value use Brazilian number formatting (comma
* as the decimal point, e.g. "70,28"), so they'll have come in as string
* variables. Swap the comma for a period, then convert to actual numbers.
replace quantity_sold = subinstr(quantity_sold, ",", ".", .)
destring quantity_sold, replace

replace royalty_value = subinstr(royalty_value, ",", ".", .)
destring royalty_value, replace

* --------------------------------------------------------------------
* Translate "substance" into English - same dictionary as SIGMINE,
* since ANM uses the same controlled vocabulary in both datasets.
* --------------------------------------------------------------------

generate substance_original = trim(substance)
label variable substance_original "Mineral substance being sold, original Portuguese text"
order substance_original, after(substance)

preserve

clear
input str60 substance_original str60 substance_english
"AGALMATOLITO" "Agalmatolite"
"ALEXANDRITA" "Alexandrite"
"ALGAS CALCÁREAS" "Calcareous algae"
"ALUMÍNIO" "Aluminum"
"ALUVIÃO AURÍFERO" "Gold-bearing alluvium"
"ALUVIÃO ESTANÍFERO" "Tin-bearing alluvium"
"AMAZONITA" "Amazonite"
"AMBLIGONITA" "Amblygonite"
"AMETISTA" "Amethyst"
"AMIANTO" "Asbestos"
"ANDALUZITA" "Andalusite"
"ANDESITO" "Andesite"
"ANFIBOLITO" "Amphibolite"
"ANFIBÓLIO" "Amphibole"
"ANIDRITA" "Anhydrite"
"ANORTOSITO" "Anorthosite"
"ANTOFILITA" "Anthophyllite"
"ANTRACITO" "Anthracite"
"APATITA" "Apatite"
"ARCÓSIO" "Arkose"
"ARDÓSIA" "Slate"
"AREIA" "Sand"
"AREIA ALUVIONAR" "Alluvial sand"
"AREIA COMUM" "Common sand"
"AREIA DE FUNDIÇÃO" "Foundry sand"
"AREIA FLUVIAL" "River sand"
"AREIA IN NATURA" "Raw sand"
"AREIA INDUSTRIAL" "Industrial sand"
"AREIA LAVADA" "Washed sand"
"AREIA P/ VIDRO" "Sand for glass"
"AREIA QUARTZOSA" "Quartz sand"
"ARENITO" "Sandstone"
"ARENITO BETUMINOSO" "Bituminous sandstone"
"ARGILA" "Clay"
"ARGILA ALUMINOSA" "Aluminous clay"
"ARGILA BENTONÍTICA" "Bentonitic clay"
"ARGILA BRANCA" "White clay"
"ARGILA CAULÍNICA" "Kaolinitic clay"
"ARGILA COMUM" "Common clay"
"ARGILA FERRUGINOSA" "Ferruginous clay"
"ARGILA P/CER. VERMELH" "Clay for red ceramics"
"ARGILA REFRATÁRIA" "Refractory clay"
"ARGILA VERMELHA" "Red clay"
"ARGILITO" "Claystone"
"ARSÊNIO" "Arsenic"
"ATAPULGITA" "Attapulgite"
"BARITA" "Barite"
"BASALTO" "Basalt"
"BASALTO P/ BRITA" "Basalt for crushed stone"
"BASALTO P/ REVESTIMENTO" "Basalt for cladding"
"BAUXITA" "Bauxite"
"BAUXITA FOSFOROSA" "Phosphorous bauxite"
"BENTONITA" "Bentonite"
"BERILO" "Beryl"
"BERÍLIO" "Beryllium"
"BIOTITA GRANITO" "Biotite granite"
"BISMUTO" "Bismuth"
"BORATOS" "Borates"
"BRITA DE GRANITO" "Crushed granite"
"CALCEDÔNIA" "Chalcedony"
"CALCITA" "Calcite"
"CALCÁRIO" "Limestone"
"CALCÁRIO CALCÍTICO" "Calcitic limestone"
"CALCÁRIO CONCHÍFERO" "Shell limestone"
"CALCÁRIO CORALÍNEO" "Coralline limestone"
"CALCÁRIO DOLOMÍTICO" "Dolomitic limestone"
"CALCÁRIO INDUSTRIAL" "Industrial limestone"
"CALCÁRIO MAGNESIANO" "Magnesian limestone"
"CALCÁRIO P/ BRITA" "Limestone for crushed stone"
"CANGA" "Laterite crust"
"CARNALITA" "Carnallite"
"CARVÃO" "Coal"
"CARVÃO MINERAL" "Mineral coal"
"CASCALHO" "Gravel"
"CASCALHO DIAMANTÍFERO" "Diamond-bearing gravel"
"CASCALHO SILICOSO" "Siliceous gravel"
"CASSITERITA" "Cassiterite"
"CATACLASITO" "Cataclasite"
"CAULIM" "Kaolin"
"CAULIM ARGILOSO" "Clayey kaolin"
"CAULINITA" "Kaolinite"
"CHARNOQUITO" "Charnockite"
"CHUMBO" "Lead"
"CIANITA" "Kyanite"
"CITRINO" "Citrine"
"COBRE" "Copper"
"COLUMBITA" "Columbite"
"CONCHAS CALCÁRIAS" "Calcareous shells"
"CONGLOMERADO" "Conglomerate"
"CORDIERITA" "Cordierite"
"CORÍNDON" "Corundum"
"CRISOBERILO" "Chrysoberyl"
"CRISOPRÁSIO" "Chrysoprase"
"CRISTAL DE ROCHA" "Rock crystal"
"CROMITA" "Chromite"
"CROMO" "Chromium"
"CÁDMIO" "Cadmium"
"DACITO" "Dacite"
"DADO NÃO CADASTRADO" "Data not registered"
"DIABÁSIO" "Diabase"
"DIABÁSIO P/ BRITA" "Diabase for crushed stone"
"DIABÁSIO P/ REVESTIMENTO" "Diabase for cladding"
"DIAMANTE" "Diamond"
"DIAMANTE INDUSTRIAL" "Industrial diamond"
"DIATOMITA" "Diatomite"
"DIATOMITO" "Diatomite"
"DIOPSÍDIO" "Diopside"
"DIORITO" "Diorite"
"DIORITO P/ BRITA" "Diorite for crushed stone"
"DOLOMITO" "Dolomite"
"DUNITO" "Dunite"
"ENDERBITO" "Enderbite"
"ENXOFRE" "Sulfur"
"ESMERALDA" "Emerald"
"ESPODUMÊNIO" "Spodumene"
"ESTANHO" "Tin"
"ESTEATITO" "Steatite"
"ESTRÔNCIO" "Strontium"
"FELDSPATO" "Feldspar"
"FERRO" "Iron"
"FERRO MANGANÊS" "Ferromanganese"
"FILITO" "Phyllite"
"FLUORITA" "Fluorite"
"FOLHELHO" "Shale"
"FOLHELHO ARGILOSO" "Clayey shale"
"FOLHELHO BETUMINOSO" "Bituminous shale"
"FOLHELHO PIROBETUMINO" "Pyrobituminous shale"
"FONÓLITO" "Phonolite"
"FOSFATO" "Phosphate"
"FOSFORITA (O)" "Phosphorite"
"GABRO" "Gabbro"
"GALENA" "Galena"
"GEMA" "Gem"
"GIBBSITA" "Gibbsite"
"GIPSITA" "Gypsite"
"GIPSO" "Gypsum"
"GNAISSE" "Gneiss"
"GNAISSE INDUSTRIAL" "Industrial gneiss"
"GNAISSE ORNAMENTAL" "Ornamental gneiss"
"GNAISSE P/ BRITA" "Gneiss for crushed stone"
"GNAISSE P/ REVESTIMENTO" "Gneiss for cladding"
"GRAFITA" "Graphite"
"GRANADA" "Garnet"
"GRANITO" "Granite"
"GRANITO GNÁISSICO" "Gneissic granite"
"GRANITO ORNAMENTAL" "Ornamental granite"
"GRANITO P/ BRITA" "Granite for crushed stone"
"GRANITO P/ REVESTIMENTO" "Granite for cladding"
"GRANODIORITO" "Granodiorite"
"GRANODIORITO INDUSTRIAL" "Industrial granodiorite"
"GRANODIORITO P/ REVESTIMENTO" "Granodiorite for cladding"
"GRANULITO" "Granulite"
"GUANO" "Guano"
"HEMATITA" "Hematite"
"HIDRARGILITA" "Hydrargillite"
"HÁFNIO" "Hafnium"
"ILMENITA" "Ilmenite"
"ITABIRITO" "Itabirite"
"KINZIGITO" "Kinzigite"
"KUNZITA" "Kunzite"
"LATERITA" "Laterite"
"LEPIDOLITA" "Lepidolite"
"LEUCITA" "Leucite"
"LEUCOFILITO" "Leucophyllite"
"LIMONITA" "Limonite"
"LINHITO" "Lignite"
"LÍTIO" "Lithium"
"MAGNESITA" "Magnesite"
"MAGNETITA" "Magnetite"
"MAGNÉSIO" "Magnesium"
"MANGANÊS" "Manganese"
"METACONGLOMERADO" "Metaconglomerate"
"MICA" "Mica"
"MICAXISTO" "Mica schist"
"MIGMATITO" "Migmatite"
"MIGMATITO INDUSTRIAL" "Industrial migmatite"
"MIGMATITO ORNAMENTAL" "Ornamental migmatite"
"MIGMATITO P/ BRITA" "Migmatite for crushed stone"
"MINÉRIO DE ALUMÍNIO" "Aluminum ore"
"MINÉRIO DE ANTIMÔNIO" "Antimony ore"
"MINÉRIO DE ARSÊNICO" "Arsenic ore"
"MINÉRIO DE BERÍLIO" "Beryllium ore"
"MINÉRIO DE BISMUTO" "Bismuth ore"
"MINÉRIO DE CHUMBO" "Lead ore"
"MINÉRIO DE COBALTO" "Cobalt ore"
"MINÉRIO DE COBRE" "Copper ore"
"MINÉRIO DE CROMO" "Chromium ore"
"MINÉRIO DE CÁDMIO" "Cadmium ore"
"MINÉRIO DE CÉRIO" "Cerium ore"
"MINÉRIO DE CÉSIO" "Cesium ore"
"MINÉRIO DE ESTANHO" "Tin ore"
"MINÉRIO DE FERRO" "Iron ore"
"MINÉRIO DE LÍTIO" "Lithium ore"
"MINÉRIO DE MAGNÉSIO" "Magnesium ore"
"MINÉRIO DE MANGANÊS" "Manganese ore"
"MINÉRIO DE MERCÚRIO" "Mercury ore"
"MINÉRIO DE MOLIBDÊNIO" "Molybdenum ore"
"MINÉRIO DE NIÓBIO" "Niobium ore"
"MINÉRIO DE NÍQUEL" "Nickel ore"
"MINÉRIO DE OURO" "Gold ore"
"MINÉRIO DE PALÁDIO" "Palladium ore"
"MINÉRIO DE PLATINA" "Platinum ore"
"MINÉRIO DE PRATA" "Silver ore"
"MINÉRIO DE RUBÍDIO" "Rubidium ore"
"MINÉRIO DE SILÍCIO" "Silicon ore"
"MINÉRIO DE TITÂNIO" "Titanium ore"
"MINÉRIO DE TUNGSTÊNIO" "Tungsten ore"
"MINÉRIO DE TÂNTALO" "Tantalum ore"
"MINÉRIO DE URÂNIO" "Uranium ore"
"MINÉRIO DE VANÁDIO" "Vanadium ore"
"MINÉRIO DE ZINCO" "Zinc ore"
"MINÉRIO DE ZIRCÔNIO" "Zirconium ore"
"MOLIBDENITA" "Molybdenite"
"MOLIBDÊNIO" "Molybdenum"
"MONAZITA" "Monazite"
"MONTMORILONITA" "Montmorillonite"
"MONZONITO" "Monzonite"
"MORGANITA" "Morganite"
"MOSCOVITA" "Muscovite"
"MÁRMORE" "Marble"
"MÁRMORE DOLOMÍTICO" "Dolomitic marble"
"MÁRMORE P/ REVESTIMENTO" "Marble for cladding"
"NEFELINA" "Nepheline"
"NEFELINA SIENITO" "Nepheline syenite"
"NITRATO DE POTÁSSIO" "Potassium nitrate"
"NIÓBIO" "Niobium"
"NÍQUEL" "Nickel"
"OCRE" "Ochre"
"OLIVINA" "Olivine"
"OPALA" "Opal"
"OURO" "Gold"
"OURO NATIVO" "Native gold"
"OURO PIGMENTO" "Orpiment"
"PALÁDIO" "Palladium"
"PEDRA CALCÁRIA" "Limestone"
"PEDRA CORADA" "Colored stone"
"PEDRA ORNAMENTAL" "Ornamental stone"
"PEDREGULHO" "Cobble gravel"
"PEGMATITO" "Pegmatite"
"PETALITA" "Petalite"
"PIRITA" "Pyrite"
"PIROCLORO" "Pyrochlore"
"PIROFILITA" "Pyrophyllite"
"PIROXENITO" "Pyroxenite"
"PLATINA" "Platinum"
"POLUCITA" "Pollucite"
"PRATA" "Silver"
"QUARTZITO" "Quartzite"
"QUARTZITO FRIÁVEL" "Friable quartzite"
"QUARTZITO INDUSTRIAL" "Industrial quartzite"
"QUARTZITO P/ REVESTIMENTO" "Quartzite for cladding"
"QUARTZITO SERICITICO" "Sericitic quartzite"
"QUARTZO" "Quartz"
"QUARTZO INDUSTRIAL" "Industrial quartz"
"RIÓLITO" "Rhyolite"
"ROCHA BETUMINOSA" "Bituminous rock"
"ROCHA FOSFÁTICA" "Phosphate rock"
"ROCHA PIROBETUMINOSA" "Pyrobituminous rock"
"ROCHA POTÁSSICA" "Potassic rock"
"RUBI" "Ruby"
"RUTILO" "Rutile"
"SAFIRA" "Sapphire"
"SAIBRO" "Coarse sand"
"SAIS DE BROMO" "Bromine salts"
"SAIS DE MAGNÉSIO" "Magnesium salts"
"SAIS DE POTÁSSIO" "Potassium salts"
"SAIS DE SÓDIO" "Sodium salts"
"SALGEMA" "Rock salt"
"SAPONITO" "Saponite"
"SAPROPELITO" "Sapropelite"
"SCHEELITA" "Scheelite"
"SEIXOS" "Pebbles"
"SEIXOS ROLADOS" "Rounded pebbles"
"SERPENTINITO" "Serpentinite"
"SIENITO" "Syenite"
"SIENITO INDUSTRIAL" "Industrial syenite"
"SIENITO ORNAMENTAL" "Ornamental syenite"
"SIENO GRANITO" "Syenogranite"
"SILICATOS DE NÍQUEL" "Nickel silicates"
"SILTITO" "Siltstone"
"SILVINITA" "Sylvinite"
"SODALITA" "Sodalite"
"SODALITA SIENITO" "Sodalite syenite"
"SULFETOS DE CHUMBO" "Lead sulfides"
"SÍLEX" "Flint"
"SÍLICA" "Silica"
"TALCO" "Talc"
"TANTALITA" "Tantalite"
"TANTALITA-COLUMBITA" "Tantalite-columbite"
"TERRAS RARAS" "Rare earths"
"TINGUAÍTO" "Tinguaite"
"TITANITA" "Titanite"
"TITÂNIO" "Titanium"
"TONALITO" "Tonalite"
"TOPÁZIO" "Topaz"
"TOPÁZIO IMPERIAL" "Imperial topaz"
"TRAQUITO" "Trachyte"
"TRIPOLITO" "Tripolite"
"TUFO" "Tuff"
"TUFO VULCÂNICO" "Volcanic tuff"
"TUNGSTÊNIO" "Tungsten"
"TURFA" "Peat"
"TURMALINA" "Tourmaline"
"TURQUESA" "Turquoise"
"TÂNTALO" "Tantalum"
"VANÁDIO" "Vanadium"
"VARVITO" "Varvite"
"VERMICULITA" "Vermiculite"
"WOLFRAMITA" "Wolframite"
"XISTO" "Schist"
"XISTO ARGILOSO" "Clayey schist"
"ZINCO" "Zinc"
"ZIRCONITA" "Zirconite"
"ZIRCÃO" "Zircon"
"ZIRCÔNIO" "Zirconium"
"ÁGATA" "Agate"
"ÁGUA MARINHA" "Aquamarine"
"ÁGUA MINERAL" "Mineral water"
"ÁGUA MINERAL ALC. BIC" "Alkaline bicarbonate mineral water"
"ÁGUA MINERAL ALC. TER. CALCI." "Alkaline earthy calcic mineral water"
"ÁGUA MINERAL CARBOGAS" "Carbonated mineral water"
"ÁGUA MINERAL RAD. FON" "Radioactive spring mineral water"
"ÁGUA POTÁVEL DE MESA" "Table drinking water"
"ÁGUA TERMO MINERAL" "Thermal mineral water"
"ÁGUAS OLIGOMINERAIS" "Oligomineral waters"
"ÁGUAS TERMAIS" "Thermal waters"
end

tempfile substance_dictionary
save "`substance_dictionary'"

restore

merge m:1 substance_original using "`substance_dictionary'", keep(1 3)

replace substance = substance_english if _merge == 3
replace substance = substance_original if _merge == 1

drop substance_english _merge

label variable substance "Mineral substance being sold"

label variable year "Year of this royalty payment record"
capture label variable month "Month of this royalty payment record"
label variable process_number "Mining process number (join key back to SIGMINE)"
label variable process_year "Year the process was originally filed"
label variable payer_type "PF (individual) or PJ (company)"
label variable taxpayer_id "CPF/CNPJ of the payer (partially redacted)"
label variable state "Brazilian state abbreviation"
label variable municipality_code "IBGE municipality code"
capture label variable municipality_name "Municipality name"
label variable quantity_sold "Quantity of mineral sold this period"
label variable unit_of_measure "Unit for quantity_sold (t, kg, l, etc.)"
label variable royalty_value "CFEM royalty value collected, in reais"

drop record_created_at


********************************************************************************
********************************************************************************
**********															 ***********
********** 						Section 3: Save                      ***********
**********															 ***********
********************************************************************************
********************************************************************************

save "`CFEM_WORKING'/cfem_process_month.dta", replace

di as result "Done - saved `=_N' royalty payment records to `CFEM_WORKING'/cfem_process_month.dta"
