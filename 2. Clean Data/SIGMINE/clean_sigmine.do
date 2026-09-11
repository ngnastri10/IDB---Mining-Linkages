* ==========================================================================
* Clean SIGMINE: build one dataset with one row per mining process.
*
* Takes the raw shapefiles pulled by
*     /1. Pull Raw Data/SIGMINE/pull_sigmine.py
* and turns them into a single Stata dataset - one row per mining
* process, active and inactive stacked together, with clear English
* variable names and labels instead of ANM's Portuguese column names.
*
* Input:
*   Data/SIGMINE/Active/BRASIL.shp              (+ .dbf, .shx, etc.)
*   Data/SIGMINE/Inactive/PROCESSOS_INATIVOS.shp (+ .dbf, .shx, etc.)
*
* Output:
*   Working/SIGMINE/sigmine_mine_level.dta
*
* Requires Stata's built-in spatial tools (spshape2dta), which need a
* reasonably modern Stata (15 or later).
*
* BEFORE running this file, run Code/config.do once in your Stata
* session.
*
*
*
* File Organization:
*
*		Section 1: Import raw data & rename variables of interest
*		Section 2: Translate variables into english
*		Section 3: Collapse to one row per mining process
* 		Section 4: Clean-up files and save
*
* ==========================================================================

clear all
set more off

if "$PROJECT_ROOT" == "" {
    di as error "PROJECT_ROOT isn't set."
    di as error "Run Code/config.do first (once per Stata session), then run this file again."
    exit 198
}

local SIGMINE_RAW     "$RAW_DIR/SIGMINE"
local SIGMINE_WORKING "$WORKING_DIR/SIGMINE"

capture mkdir "`SIGMINE_WORKING'"


********************************************************************************
********************************************************************************
**********															 ***********
********** Section 1: Import raw data & rename variables of interest ***********
**********															 ***********
********************************************************************************
********************************************************************************

* --------------------------------------------------------------------
* Convert each shapefile to Stata format, tag which file it came from,
* and stack the two into one dataset.
* --------------------------------------------------------------------

cd "`SIGMINE_WORKING'"

* --- Active processes ---
spshape2dta "`SIGMINE_RAW'/Active/BRASIL", replace saving(temp_active)
use "temp_active.dta", clear
generate byte active_process = 1
save "temp_active.dta", replace

* --- Inactive / closed processes ---
spshape2dta "`SIGMINE_RAW'/Inactive/PROCESSOS_INATIVOS", replace saving(temp_inactive)
use "temp_inactive.dta", clear
generate byte active_process = 0
save "temp_inactive.dta", replace

* --- Stack them together: one row per process either way ---
use "temp_active.dta", clear
append using "temp_inactive.dta"

* --------------------------------------------------------------------
* Rename Portuguese/coded column names to clear English ones
* --------------------------------------------------------------------

rename (PROCESSO NUMERO ANO AREA_HA ID FASE ULT_EVENTO NOME SUBS USO UF DSProcesso _CX _CY) ///
       (process_id_full process_number process_year area_hectares sigmine_internal_id phase last_event holder_name substance use_type state process_description centroid_lon centroid_lat)

capture drop _ID

* labels get set later, in Section 4 - collapse (Section 3) wipes them,
* so no point setting them before that.


********************************************************************************
********************************************************************************
**********															 ***********
********** 			Section 2: Translate variables into english 	 ***********
**********															 ***********
********************************************************************************
********************************************************************************

* --------------------------------------------------------------------
* Translate "phase" into English. The original Portuguese is kept in phase_original.
* --------------------------------------------------------------------

generate phase_original = trim(phase)
order phase_original, after(phase)

replace phase = cond(phase_original == "APTO PARA DISPONIBILIDADE", "Eligible for availability", ///
            cond(phase_original == "AUTORIZAÇÃO DE PESQUISA", "Exploration authorization", ///
            cond(phase_original == "CONCESSÃO DE LAVRA", "Mining concession", ///
            cond(phase_original == "DADO NÃO CADASTRADO", "Data not registered", ///
            cond(phase_original == "DIREITO DE REQUERER A LAVRA", "Right to request mining concession", ///
            cond(phase_original == "DISPONIBILIDADE", "Available", ///
            cond(phase_original == "LAVRA GARIMPEIRA", "Artisanal mining", ///
            cond(phase_original == "LICENCIAMENTO", "Licensing", ///
            cond(phase_original == "RECONHECIMENTO GEOLÓGICO", "Geological reconnaissance", ///
            cond(phase_original == "REGISTRO DE EXTRAÇÃO", "Extraction registration", ///
            cond(phase_original == "REQUERIMENTO DE LAVRA", "Mining concession request", ///
            cond(phase_original == "REQUERIMENTO DE LAVRA GARIMPEIRA", "Artisanal mining request", ///
            cond(phase_original == "REQUERIMENTO DE LICENCIAMENTO", "Licensing request", ///
            cond(phase_original == "REQUERIMENTO DE PESQUISA", "Exploration request", ///
            cond(phase_original == "REQUERIMENTO DE REGISTRO DE EXTRAÇÃO", "Extraction registration request", ///
            phase_original)))))))))))))))

* --------------------------------------------------------------------
* Translate "substance" into English.
*
* This list is much bigger than "phase" so instead this builds a small lookup table and merges it onto the data by substance.
* --------------------------------------------------------------------

generate substance_original = trim(substance)
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

********************************************************************************
********************************************************************************
**********															 ***********
********** Section 3: Collapse to one row per mining process         ***********
**********															 ***********
********************************************************************************
********************************************************************************

/* Notes:

SIGMINE file comes in parcels not individual mines. Collapse this down to get 
a unique observation per mine. 

A small portion of mines (~3%) have duplicate (one in the active
and another in the inactive section) so fix those duplicates.
*/


* --- handle the active/inactive case first ---
* A process has both an active and an inactive copy exactly when the
* min of active_process across its rows is 0 and the max is 1.
bysort process_number process_year: egen byte min_active = min(active_process)
bysort process_number process_year: egen byte max_active = max(active_process)
generate byte has_both_statuses = (min_active == 0 & max_active == 1)

* the inactive copy is the blank one - drop it, keep the informative row(s)
drop if has_both_statuses == 1 & active_process == 0

* record that these processes are actually closed today, even though
* we're keeping the data from when they were still active
replace active_process = 0 if has_both_statuses == 1

drop min_active max_active has_both_statuses

* --- now collapse the remaining (parcel-level) duplicates ---
* area_hectares sums across parcels; everything else should already be
* identical within a process at this point, so "first" just picks it up.
collapse (sum) area_hectares ///
         (first) process_id_full sigmine_internal_id phase phase_original ///
                 last_event holder_name substance substance_original use_type ///
                 state process_description centroid_lon centroid_lat active_process, ///
         by(process_number process_year)





********************************************************************************
********************************************************************************
**********															 ***********
********** 				Section 4: Clean-up files and save           ***********
**********															 ***********
********************************************************************************
********************************************************************************

* --------------------------------------------------------------------
* Label variables
* --------------------------------------------------------------------

local newnames process_id_full process_number process_year area_hectares ///
    sigmine_internal_id phase phase_original last_event holder_name substance ///
    substance_original use_type state process_description centroid_lon ///
    centroid_lat active_process

foreach v of local newnames {

    local lbl = cond("`v'" == "process_id_full", "Full process ID, number and year", ///
                cond("`v'" == "process_number", "Process number, without the year", ///
                cond("`v'" == "process_year", "Year the process was originally filed", ///
                cond("`v'" == "area_hectares", "Total area of the claim or concession across all parcels, in hectares", ///
                cond("`v'" == "sigmine_internal_id", "ANM's internal SIGMINE record ID", ///
                cond("`v'" == "phase", "Current stage in ANM's permitting pipeline", ///
                cond("`v'" == "phase_original", "Current stage in ANM's permitting pipeline, original Portuguese text", ///
                cond("`v'" == "last_event", "Most recent recorded event or status update", ///
                cond("`v'" == "holder_name", "Name of the process's titleholder", ///
                cond("`v'" == "substance", "Mineral substance being claimed or extracted", ///
                cond("`v'" == "substance_original", "Mineral substance being claimed or extracted, original Portuguese text", ///
                cond("`v'" == "use_type", "Intended use of the extracted substance", ///
                cond("`v'" == "state", "Brazilian state abbreviation", ///
                cond("`v'" == "process_description", "Free-text description of the process", ///
                cond("`v'" == "centroid_lon", "Approximate longitude of the claim's centroid", ///
                cond("`v'" == "centroid_lat", "Approximate latitude of the claim's centroid", ///
                cond("`v'" == "active_process", "Which SIGMINE file this process came from", ///
                "Error `v'")))))))))))))))))

    label variable `v' "`lbl'"

}

label define active_lbl 0 "Inactive / closed" 1 "Active"
label values active_process active_lbl

* --------------------------------------------------------------------
* Save the final dataset and clean up the temporary files we no longer
* need.
* --------------------------------------------------------------------

save "`SIGMINE_WORKING'/sigmine_mine_level.dta", replace

local delete = "temp_active temp_active_shp temp_inactive temp_inactive_shp"

foreach del in `delete' {

capture erase "`SIGMINE_WORKING'/`del'.dta"

}
