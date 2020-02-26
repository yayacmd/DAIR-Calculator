#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(shinyBS)
library(shinyWidgets)
library(flexdashboard)
library(plotly)
library(randomForest)
library(httr)
library(xml2)
rfall<-readRDS("www/DAIR.rds",.GlobalEnv)
rfall2<-readRDS("www/DAIR2.rds",.GlobalEnv)

API<-GET("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=debridement+antibiotic+implant+retention&sort=date&api_key=52aa0b8c79dd84a1f891901d7a5a3defd309")
PMID<-as.numeric(xml_text(xml_find_all(read_xml(content(API,"text")),"//Id")))
Date<-vector(mode="character",length=5)
Date<-c(API$date,API$date,API$date,API$date,API$date)
Author<-vector(mode="character",length=5)
Title<-vector(mode="character",length=5)
Journal<-vector(mode="character",length=5)
Volume<-vector(mode="character",length=5)
Abstract<-vector(mode="character",length=5)
Issue<-vector(mode="character",length=5)
Pubdate<-vector(mode="character",length=5)
URL<-vector(mode="character",length=5)
for (i in 1:5) {url=paste0("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&format=xml&api_key=52aa0b8c79dd84a1f891901d7a5a3defd309&id=",PMID[i])
meta<-GET(url)
URL[i]<-paste0("https://pubmed.ncbi.nlm.nih.gov/",PMID[i])
Title[i]<-xml_text(xml_find_first(read_xml(content(meta,"text")),"//ArticleTitle"))
Author[i]<-paste0(xml_text(xml_find_first(read_xml(content(meta,"text")),"//Author/LastName"))," ","et al.")
Journal[i]<-paste0(xml_text(xml_find_first(read_xml(content(meta,"text")),"//Journal/Title")))
Volume[i]<-paste0("Volume ",xml_text(xml_find_first(read_xml(content(meta,"text")),"//Volume")))
Issue[i]<-paste0("Issue ",xml_text(xml_find_first(read_xml(content(meta,"text")),"//Issue")))
Pubdate[i]<-paste0("Published: ",xml_text(xml_find_first(read_xml(content(meta,"text")),"//PubDate/Month"))," ",xml_text(xml_find_first(read_xml(content(meta,"text")),"//PubDate/Year")))
Abstract[i]<-xml_text(xml_find_first(read_xml(content(meta,"text")),"//Abstract/AbstractText"))
Sys.sleep(0.05)}


ui <- fluidPage(
    setBackgroundColor(
        color = "white",
        gradient = c("linear", "radial"),
        direction = c("bottom", "top", "right", "left"),
        shinydashboard = FALSE
    ),tags$script(src="myscript.js"),
    tags$head(includeScript("www/google-analytics.js"),tags$style("figure{border-width:10px; border-style:solid;border-color:black;border-radius:25px}","h4{color:white;}","h2{color:white;}","@media (hover:none) {.sbs-toggle-button.active:hover{background-color:black;color:white;}}","@media (hover:none) {.sbs-toggle-button:hover{background-color:white;color:black}}",".btn.active{background-color:black;color:white;}",".btn.active:hover{background-color:black;color:white;}",".btn.active:focus{background-color:black;color:white;}",".panel-heading{color:white;background-color:Black;}",".btn{margin-bottom:5px;margin-left:5px;margin-right:5px;font-size:small;width:100%;text-align:center;}"),
    ),
    tags$h1(align="center","Debridement and Implant Retention (DAIR) Success Calculator"),
    
    sidebarLayout(sidebarPanel(width=4,tags$style(".well {background-color:Black;}"),
        fluidRow(tags$h2(align="center","Probability of Treatment Success"),
                              tags$h4(align="center",gaugeOutput("value")),
                              tags$h4(align="center",switchInput("Mobilexchange","Modular Component Exchange",value = FALSE,onLabel="Yes",offLabel = "No",onStatus="success",offStatus="danger",size="large",inline = TRUE))
                              )),
    
        mainPanel(width=8,
            bsCollapse(multiple = TRUE,open = "Risk Factors for Failure",
                bsCollapsePanel(title="Patient Demographics",style = "dark",
                    column(6,numericInput("Age", "Patient Age (years)", min = 0, max = 100, value = 75, step =1),
                    radioGroupButtons("Male", "Patient Gender",selected = "1",direction = "horizontal",individual = TRUE,choiceNames = list("Male","Female"),choiceValues = list("1","0"))),
                    column(6,numericInput("BMI", HTML(paste("Body Mass Index (kg/m",tags$sup(2),")",sep="")), min = 10, max = 100, value = 25, step =0.1),
                    tags$h5(HTML("<b>Social Factors<b/>")),
                    column(6,bsButton("Smoking",HTML("Current<br/>Smoker"),value = FALSE,type = "toggle")),
                    column(6,bsButton("Alcohol",HTML("Current<br/>Alcohol Use"),value = FALSE,type = "toggle")
                    ))),
                bsCollapsePanel(title="Patient Comorbidities",style ="dark",
                    column(7,
                        bsButton("COPD","Chronic Obstructive Pulmonary Disease",value = FALSE,type="toggle"),   
                        bsButton("Immunesuppresion","Immunocompromised",value = FALSE,type="toggle"),
                        bsButton("Pacemaker_ICD","Pacemaker or ICD Implanted",value = FALSE,type="toggle"),
                        bsButton("oral_anticoagulant","Taking Oral Anticoagulant Agent",value = FALSE,type="toggle"),
                        bsButton("RA","Rheumatoid Arthritis",value = FALSE,type="toggle"),
                        bsButton("HF","Congestive Heart Failure",value = FALSE,type="toggle"),
                        bsButton("CRF","Chronic Kidney Disease",value = FALSE,type="toggle")),
                    column(5,
                        bsButton("LC","Liver Cirrhosis",value = FALSE,type="toggle"),
                        bsButton("malignancy","Cancer",value = FALSE,type="toggle"),
                        bsButton("Hypertension","Hypertension",value = FALSE,type="toggle"),
                        bsButton("IHD","Hemodialysis",value = FALSE,type="toggle"),
                        bsButton("Dementia","Dementia",value = FALSE,type="toggle",style="default"),
                        bsButton("DM","Diabetes Mellitus",value = FALSE,type="toggle")
                    )
                ),
                bsCollapsePanel(title = "Procedure",style="dark",
                column(4,
                       radioGroupButtons("Indication_prosthesis", "Indication for Arthroplasty", choiceNames = list("Osteoarthritis","Other"), choiceValues = list("1","2"),direction = "vertical",individual = TRUE),
                       radioGroupButtons("Joint", "Joint", choiceNames = list("Hip","Knee"), choiceValues = list("1","2"),direction = "horizontal",individual = TRUE)
                    ),
                column(4,
                       radioGroupButtons("index_revision", "Index Procedure", choiceNames = list("Primary","Revision"), choiceValues = list("0","1"),direction = "horizontal",individual = TRUE),
                       radioGroupButtons("Cement","Cemented Components", choiceNames = list("Yes","No"),choiceValues = list("1","0"),direction = "horizontal",individual = TRUE),
                       radioGroupButtons("late_infection","Late infection",choiceNames = list("Yes","No"),choiceValues = list("1","0"),direction = "horizontal",individual = TRUE)
                    ),
                column(4,
                    numericInput("days_to_DAIR", HTML("Days from Index <br/> Procedure to DAIR"), min = 0, max = 200, value = 0, step =1),
                    numericInput("Dayssymptoms", "Days of Symptoms", min = 0, max = 100, value = 0, step =1)
                    )
                ),
                bsCollapsePanel(title="Complications",style="dark",
                    column(4,
                        bsButton("Wound_leakage","Wound Leakage",value = FALSE,type="toggle"),
                        bsButton("Necrosis","Necrosis",value = FALSE,type="toggle")
                       ),
                    column(4,
                        bsButton("Fistula","Fistula Present",value = FALSE,type="toggle"),
                        bsButton("Fever38","Fever",value = FALSE,type="toggle")
                       ),
                    column(4,
                        bsButton("Skin_infection",HTML("Overlying Skin<br/>Infection"),value = FALSE,type="toggle")
                       )
                ),
                bsCollapsePanel(title = "Laboratory and Culture Results",style ="dark",
                fluidRow(column(5,
                                numericInput("Last_CRP", "Last C-Reactive Protein (CRP) Level (mg/L)", min = 0, max = 100, value = 1.8, step =0.1)),
                    column(4,numericInput("Last_leucocytes", "Last Leucocyte Count (1,000 cells/mL)", min = 0, max = 100, value = 13, step =0.1)),
                    column(3,bsButton("Positive_bloodcultures",HTML("Positive Blood <br/> Cultures"),value = FALSE,type="toggle"))),
                
                    fluidRow(column(6,tags$h4(style="color:black;background-color:white;text-align:center;padding:20px;",tags$strong("Were Cultures Obtained?"))),
                    column(6,radioGroupButtons("Culture","",choiceNames = list("Yes","No"),choiceValues = list("1","0"),direction = "horizontal",individual = TRUE,selected = "0",size="lg",justified = TRUE,width="100%"))),
                    conditionalPanel(condition = "input.Culture=='1'",
                    fluidRow(panel(heading = "Organism (select all that apply)",status = "default",
                    fluidRow(column(12,bsButton("CultureNeg","Culture Negative",value =FALSE,type="toggle",width="100%"))),
                    fluidRow(column(5,bsButton("STAU","Methicillin-sensitive S. aureus",value = FALSE,type="toggle"),
                    bsButton("MRSA","Methicillin-resistant S. aureus",value = FALSE,type="toggle"),
                    bsButton("Staphepi","Staphylococcus epidermidis",value = FALSE,type="toggle"),
                    bsButton("Pseudomonas_aerugi0sa","Pseudomonas aeruginosa",value = FALSE,type="toggle")),
                    column(4,bsButton("gramnegative","Gram-negative",value = FALSE,type="toggle"),
                    bsButton("Enterococcus_spp","Enterococcus",value = FALSE,type="toggle"),
                    bsButton("Enterobacter_spp","Enterobacter",value = FALSE,type="toggle"),
                    bsButton("Streptococci_spp","Streptococcus",value = FALSE,type="toggle")),
                    column(3,bsButton("Polymicrob","Polymicrobial",value = FALSE,type="toggle"),
                    bsButton("Proteus_spp","Proteus",value = FALSE,type="toggle"),
                    bsButton("Escherichia_coli","E. coli",value = FALSE,type="toggle"),
                    bsButton("Candida_spp","Candida",value = FALSE,type="toggle"))
                    ))))
                ),
                bsCollapsePanel(title="Risk Factors for Failure",style="dark",
                                tags$h3(align="center","Top 10 Contributing Risk Factors for Treatment Failure"),
                                tags$figure(plotlyOutput("plot")),
                                tags$p(style="font-size:x-small;margin-left:20px;font-style:italic","Percentages displayed represent the improvement in probability of success that can be achieved by changing the corresponding variable")),
                bsCollapsePanel(title=HTML("<i class='fa fa-info-circle'></i> Information"),style="dark",
                tags$p("This calculator was developed using the predictive model published in BJJ 2020 Hip Society Proceedings:",HTML("<br/>")),
                     tags$p(tags$u(tags$a(href="www","Who Will Fail Following Irrigation and Debridement for Periprosthetic Joint Infection: A Machine Learning Based Validated Tool")),HTML("<br/>"),
                     "Noam Shohat MD, Karan Goswami MD, Tim Tan MD, Michael Yayac MD, Alex Soriano MD, Ricardo Sousa MD, Marjan Wouthuyzen-Bakker MD, Javad Parvizi MD FRCS; on behalf of the: ",HTML("<br/>"),
                    tags$p(tags$u(tags$a(href="https://www.escmid.org/research_projects/study_groups/implant_infections/","ESCMID Study Group of Implant Associated Infections (ESGIAI)")),HTML("<br/>"),
                    "Northern Infection Network of Joint Arthroplasty (NINJA)"),
                    tags$footer(style="font-size:x-small;bottom:0px","Copyright",icon("copyright"),"2020 International Consensus Group LLC",HTML("<br/>"),"App developed by Michael Yayac & Kristen Nicholson"))),
                bsCollapsePanel(title="Useful Links",style="dark",
                    tags$h4(style="color:black;background-color:white",tags$u(tags$a(href="Hip-and-Knee_ICM.pdf",target="_blank","Second International Consensus Meeting (ICM) Hip and Knee Section on DAIR")),
                                tags$h4(style="color:black;background-color:white",tags$u("Recently Published Articles on DAIR")),
                                tags$p("1.",tags$u(tags$a(href=URL[1],target="_blank",Title[1])),HTML("<br/>&nbsp&nbsp&nbsp"),Author[1],",",Journal[1],"-",Volume[1],Issue[1],",",Pubdate[1],HTML("<br/>"),
                                       bsCollapsePanel(title="Abstract",
                                                       Abstract[1]),
                                       "2.",tags$u(tags$a(href=URL[2],target="_blank",Title[2])),HTML("<br/>&nbsp&nbsp&nbsp"),Author[2],",",Journal[2],"-",Volume[2],Issue[2],",",Pubdate[2],HTML("<br/>"),
                                       bsCollapsePanel(title="Abstract",
                                                       Abstract[2]),
                                       "3.",tags$u(tags$a(href=URL[3],target="_blank",Title[3])),HTML("<br/>&nbsp&nbsp&nbsp"),Author[3],",",Journal[3],"-",Volume[3],Issue[3],",",Pubdate[3],HTML("<br/>"),
                                       bsCollapsePanel(title="Abstract",
                                                       Abstract[3]),
                                       "4.",tags$u(tags$a(href=URL[4],target="_blank",Title[4])),HTML("<br/>&nbsp&nbsp&nbsp"),Author[4],",",Journal[4],"-",Volume[4],Issue[4],",",Pubdate[4],HTML("<br/>"),
                                       bsCollapsePanel(title="Abstract",
                                                       Abstract[4]),
                                       "5.",tags$u(tags$a(href=URL[5],target="_blank",Title[5])),HTML("<br/>&nbsp&nbsp&nbsp"),Author[5],",",Journal[5],"-",Volume[5],Issue[5],",",Pubdate[5],HTML("<br/>"),
                                       bsCollapsePanel(title="Abstract",
                                                       Abstract[5]))
                                
            ))
            ))))
server<-function(input,output,session) {
    
    observeEvent(input$CultureNeg=="1", ({
        updateButton(session,"MRSA", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Candida_spp", value = "0",disabled = input$CultureNeg)
        updateButton(session,"STAU", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Polymicrob", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Staphepi", value = "0",disabled = input$CultureNeg)
        updateButton(session,"gramnegative", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Escherichia_coli", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Enterobacter_spp", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Pseudomonas_aerugi0sa", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Proteus_spp", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Enterococcus_spp", value = "0",disabled = input$CultureNeg)
        updateButton(session,"Streptococci_spp", value = "0",disabled = input$CultureNeg)}))
    
    output$value<-renderGauge({
    late_infection<-as.integer(input$late_infection)
    Male<-as.integer(input$Male)
    Age<-as.numeric(input$Age)
    BMI<-as.numeric(input$BMI)
    Smoking<-as.integer(input$Smoking)
    Alcohol<-as.integer(input$Alcohol)
    Dementia<-as.integer(input$Dementia)
    Hypertension<-as.integer(input$Hypertension)
    IHD<-as.integer(input$IHD)
    HF<-as.integer(input$HF)
    oral_anticoagulant<-as.integer(input$oral_anticoagulant)
    DM<-as.integer(input$DM)
    COPD<-as.integer(input$COPD)
    CRF<-as.integer(input$CRF)
    LC<-as.integer(input$LC)
    Immunesuppresion<-as.integer(input$Immunesuppresion)
    malignancy<-as.integer(input$malignancy)
    RA<-as.integer(input$RA)
    Pacemaker_ICD<-as.integer(input$Pacemaker_ICD)
    days_to_DAIR<-as.numeric(input$days_to_DAIR)
    Indication_prosthesis<-as.integer(input$Indication_prosthesis)
    index_revision<-as.integer(input$index_revision)
    Cement<-as.integer(input$Cement)
    Joint<-as.integer(input$Joint)
    Wound_leakage<-as.integer(input$Wound_leakage)
    Necrosis<-as.integer(input$Necrosis)
    Fistula<-as.integer(input$Fistula)
    Last_CRP<-as.numeric(input$Last_CRP)
    Last_leucocytes<-as.numeric(input$Last_leucocytes)
    Fever38<-as.integer(input$Fever38)
    Positive_bloodcultures<-as.integer(input$Positive_bloodcultures)
    Skin_infection<-as.integer(input$Skin_infection)
    Mobilexchange<-as.integer(input$Mobilexchange)
    Polymicrob<-as.integer(input$Polymicrob)
    STAU<-as.integer(input$STAU)
    MRSA<-as.integer(input$MRSA)
    Staphepi<-as.integer(input$Staphepi)
    gramnegative<-as.integer(input$gramnegative)
    Escherichia_coli<-as.integer(input$Escherichia_coli)
    Enterobacter_spp<-as.integer(input$Enterobacter_spp)
    Pseudomonas_aerugi0sa<-as.integer(input$Pseudomonas_aerugi0sa)
    Proteus_spp<-as.integer(input$Proteus_spp)
    Enterococcus_spp<-as.integer(input$Enterococcus_spp)
    Streptococci_spp<-as.integer(input$Streptococci_spp)
    Candida_spp<-as.integer(input$Candida_spp)
    Dayssymptoms<-as.numeric(input$Dayssymptoms)
    
    #Combine variables into vector
    Patient<-c(late_infection,Male,Age,BMI,Smoking,Alcohol,Dementia,Hypertension,IHD,HF,oral_anticoagulant,DM,COPD,CRF,LC,Immunesuppresion,malignancy,RA,Pacemaker_ICD,days_to_DAIR,Indication_prosthesis,index_revision,Cement,Joint,Wound_leakage,Necrosis,Fistula,Last_CRP,Last_leucocytes,Fever38,Positive_bloodcultures,Skin_infection,Mobilexchange,Polymicrob,STAU,MRSA,Staphepi,gramnegative,Escherichia_coli,Enterobacter_spp,Pseudomonas_aerugi0sa,Proteus_spp,Enterococcus_spp,Streptococci_spp,Candida_spp,Dayssymptoms)
    
    #Convert vector into dataframe
    data<-t(as.data.frame(Patient,row.names=c("late_infection", "Male", "Age", "BMI", "Smoking", "Alcohol","Dementia", "Hypertension", "IHD", "HF", "oral_anticoagulant", "DM","COPD", "CRF", "LC", "Immunesuppresion", "malignancy", "RA", "Pacemaker_ICD", "days_to_DAIR", "Indication_prosthesis", "index_revision", "Cement", "Joint", "Wound_leakage", "Necrosis", "Fistula", "Last_CRP", "Last_leucocytes", "Fever38", "Positive_bloodcultures", "Skin_infection", "Mobilexchange", "Polymicrob", "STAU", "MRSA", "Staphepi", "gramnegative", "Escherichia_coli", "Enterobacter_spp", "Pseudomonas_aerugi0sa", "Proteus_spp", "Enterococcus_spp", "Streptococci_spp", "Candida_spp", "Dayssymptoms"),optional = FALSE,make.names=TRUE))
    data<-as.data.frame(data)
    
    #Convert num variables into factors
    data[,c(3,4,20,28,29,46)]<- lapply(data[,c(3,4,20,28,29,46)],as.numeric)
    data[,c(21,24)] <- lapply(data[,c(21,24)] , factor,levels=c("1","2"))
    data[,c(1:2,5:19,22,23,25:27,30:45)] <- lapply(data[,c(1:2,5:19,22,23,25:27,30:45)] ,factor, levels=c("0","1"))
    
    #Run predictive model and plot probability of success
    if(input$Culture=="0") {pred<-predict(rfall2,data,type="prob")[,2]} else  {pred<- predict(rfall,data,type="prob")[,2]}
    gauge((pred*100), 
          min = 0, 
          max = 100, 
          symbol = "%",
          sectors = gaugeSectors(success = c(67, 100), 
                                 warning = c(33, 67),
                                 danger = c(0, 33)))
   })
   output$plot<-renderPlotly({
       
       late_infection<-as.integer(input$late_infection)
       Male<-as.integer(input$Male)
       Age<-as.numeric(input$Age)
       BMI<-as.numeric(input$BMI)
       Smoking<-as.integer(input$Smoking)
       Alcohol<-as.integer(input$Alcohol)
       Dementia<-as.integer(input$Dementia)
       Hypertension<-as.integer(input$Hypertension)
       IHD<-as.integer(input$IHD)
       HF<-as.integer(input$HF)
       oral_anticoagulant<-as.integer(input$oral_anticoagulant)
       DM<-as.integer(input$DM)
       COPD<-as.integer(input$COPD)
       CRF<-as.integer(input$CRF)
       LC<-as.integer(input$LC)
       Immunesuppresion<-as.integer(input$Immunesuppresion)
       malignancy<-as.integer(input$malignancy)
       RA<-as.integer(input$RA)
       Pacemaker_ICD<-as.integer(input$Pacemaker_ICD)
       days_to_DAIR<-as.numeric(input$days_to_DAIR)
       Indication_prosthesis<-as.integer(input$Indication_prosthesis)
       index_revision<-as.integer(input$index_revision)
       Cement<-as.integer(input$Cement)
       Joint<-as.integer(input$Joint)
       Wound_leakage<-as.integer(input$Wound_leakage)
       Necrosis<-as.integer(input$Necrosis)
       Fistula<-as.integer(input$Fistula)
       Last_CRP<-as.numeric(input$Last_CRP)
       Last_leucocytes<-as.numeric(input$Last_leucocytes)
       Fever38<-as.integer(input$Fever38)
       Positive_bloodcultures<-as.integer(input$Positive_bloodcultures)
       Skin_infection<-as.integer(input$Skin_infection)
       Mobilexchange<-as.integer(input$Mobilexchange)
       Polymicrob<-as.integer(input$Polymicrob)
       STAU<-as.integer(input$STAU)
       MRSA<-as.integer(input$MRSA)
       Staphepi<-as.integer(input$Staphepi)
       gramnegative<-as.integer(input$gramnegative)
       Escherichia_coli<-as.integer(input$Escherichia_coli)
       Enterobacter_spp<-as.integer(input$Enterobacter_spp)
       Pseudomonas_aerugi0sa<-as.integer(input$Pseudomonas_aerugi0sa)
       Proteus_spp<-as.integer(input$Proteus_spp)
       Enterococcus_spp<-as.integer(input$Enterococcus_spp)
       Streptococci_spp<-as.integer(input$Streptococci_spp)
       Candida_spp<-as.integer(input$Candida_spp)
       Dayssymptoms<-as.numeric(input$Dayssymptoms)
       if(input$Culture=="0") {model<-rfall2} else {model<-rfall}
       
       #Combine variables into vector
       Patient<-c(late_infection,Male,Age,BMI,Smoking,Alcohol,Dementia,Hypertension,IHD,HF,oral_anticoagulant,DM,COPD,CRF,LC,Immunesuppresion,malignancy,RA,Pacemaker_ICD,days_to_DAIR,Indication_prosthesis,index_revision,Cement,Joint,Wound_leakage,Necrosis,Fistula,Last_CRP,Last_leucocytes,Fever38,Positive_bloodcultures,Skin_infection,Mobilexchange,Polymicrob,STAU,MRSA,Staphepi,gramnegative,Escherichia_coli,Enterobacter_spp,Pseudomonas_aerugi0sa,Proteus_spp,Enterococcus_spp,Streptococci_spp,Candida_spp,Dayssymptoms)
       
       #Convert vector into dataframe
       data<-t(as.data.frame(Patient,row.names=c("late_infection", "Male", "Age", "BMI", "Smoking", "Alcohol","Dementia", "Hypertension", "IHD", "HF", "oral_anticoagulant", "DM","COPD", "CRF", "LC", "Immunesuppresion", "malignancy", "RA", "Pacemaker_ICD", "days_to_DAIR", "Indication_prosthesis", "index_revision", "Cement", "Joint", "Wound_leakage", "Necrosis", "Fistula", "Last_CRP", "Last_leucocytes", "Fever38", "Positive_bloodcultures", "Skin_infection", "Mobilexchange", "Polymicrob", "STAU", "MRSA", "Staphepi", "gramnegative", "Escherichia_coli", "Enterobacter_spp", "Pseudomonas_aerugi0sa", "Proteus_spp", "Enterococcus_spp", "Streptococci_spp", "Candida_spp", "Dayssymptoms"),optional = FALSE,make.names=TRUE))
       data<-as.data.frame(data)
       
       #Convert num variables into factors
       data[,c(3,4,20,28,29,46)]<- lapply(data[,c(3,4,20,28,29,46)],as.numeric)
       data[,c(21,24)] <- lapply(data[,c(21,24)] , factor,levels=c("1","2"))
       data[,c(1:2,5:19,22,23,25:27,30:45)] <- lapply(data[,c(1:2,5:19,22,23,25:27,30:45)] ,factor, levels=c("0","1"))
       
       #Run predictive model and plot probability of success
       pred<- predict(model,data,type="prob")[,2]
       
       #Marginal Effect of Late Infection
       if (data$late_infection==1) {testnew1 = data
       testnew1$late_infection[testnew1$late_infection=='1']<-'0'
       late_infectionNew<-predict(model,testnew1,type="prob")[,2]
       late_infectionDep<-(late_infectionNew-pred)*100
       } else {testnew1 = data
       testnew1$late_infection[testnew1$late_infection=='0']<-'1'
       late_infectionNew<-predict(model,testnew1,type="prob")[,2]
       late_infectionDep<-(late_infectionNew-pred)*100}
       
       #Marginal Effect of Gender
       if (data$Male==1) {testnew2 = data
       testnew2$Male[testnew2$Male=='1']<-'0'
       MaleNew<-predict(model,testnew2,type="prob")[,2]
       MaleDep<-(MaleNew-pred)*100
       } else {testnew2 = data
       testnew2$Male[testnew2$Male=='0']<-'1'
       MaleNew<-predict(model,testnew2,type="prob")[,2]
       MaleDep<-(MaleNew-pred)*100}
       
       #Marginal Effect of Age
       if (data$Age!=75) {testnew3=data
       testnew3$Age<-75
       AgeNew<-predict(model,testnew3,type="prob")[,2]
       AgeDep<-(AgeNew-pred)*100
       } else {AgeDep<-0}
       
       #Marginal Effect of BMI
       if (data$BMI!=26.5) {testnew4=data
       testnew4$BMI<-26.5
       BMINew<-predict(model,testnew4,type="prob")[,2]
       BMIDep<-(BMINew-pred)*100
       } else {BMIDep<-0}
       
       #Marginal Effect of Smoking
       if (data$Smoking==1) {testnew5 = data
       testnew5$Smoking[testnew5$Smoking=='1']<-'0'
       SmokingNew<-predict(model,testnew5,type="prob")[,2]
       SmokingDep<-(SmokingNew-pred)*100
       } else {testnew5 = data
       testnew5$Smoking[testnew5$Smoking=='0']<-'1'
       SmokingNew<-predict(model,testnew5,type="prob")[,2]
       SmokingDep<-(SmokingNew-pred)*100}
       
       #Marginal Effect of Alcohol
       if (data$Alcohol==1) {testnew6 = data
       testnew6$Alcohol[testnew6$Alcohol=='1']<-'0'
       AlcoholNew<-predict(model,testnew6,type="prob")[,2]
       AlcoholDep<-(AlcoholNew-pred)*100
       } else {testnew6 = data
       testnew6$Alcohol[testnew6$Alcohol=='0']<-'1'
       AlcoholNew<-predict(model,testnew6,type="prob")[,2]
       AlcoholDep<-(AlcoholNew-pred)*100}
       
       #Marginal Effect of Dementia
       if (data$Dementia==1) {testnew7 = data
       testnew7$Dementia[testnew7$Dementia=='1']<-'0'
       DementiaNew<-predict(model,testnew7,type="prob")[,2]
       DementiaDep<-(DementiaNew-pred)*100
       } else {testnew7 = data
       testnew7$Dementia[testnew7$Dementia=='0']<-'1'
       DementiaNew<-predict(model,testnew7,type="prob")[,2]
       DementiaDep<-(DementiaNew-pred)*100}
       
       #Marginal Effect of Hypertension
       if (data$Hypertension==1) {testnew8 = data
       testnew8$Hypertension[testnew8$Hypertension=='1']<-'0'
       HypertensionNew<-predict(model,testnew8,type="prob")[,2]
       HypertensionDep<-(HypertensionNew-pred)*100
       } else {testnew8 = data
       testnew8$Hypertension[testnew8$Hypertension=='0']<-'1'
       HypertensionNew<-predict(model,testnew8,type="prob")[,2]
       HypertensionDep<-(HypertensionNew-pred)*100}
       
       #Marginal Effect of IHD
       if (data$IHD==1) {testnew9 = data
       testnew9$IHD[testnew9$IHD=='1']<-'0'
       IHDNew<-predict(model,testnew9,type="prob")[,2]
       IHDDep<-(IHDNew-pred)*100
       } else {testnew9 = data
       testnew9$IHD[testnew9$IHD=='0']<-'1'
       IHDNew<-predict(model,testnew9,type="prob")[,2]
       IHDDep<-(IHDNew-pred)*100}
       
       #Marginal Effect of HF
       if (data$HF==1) {testnew10 = data
       testnew10$HF[testnew10$HF=='1']<-'0'
       HFNew<-predict(model,testnew10,type="prob")[,2]
       HFDep<-(HFNew-pred)*100
       } else {testnew10 = data
       testnew10$HF[testnew10$HF=='0']<-'1'
       HFNew<-predict(model,testnew10,type="prob")[,2]
       HFDep<-(HFNew-pred)*100}
       
       #Marginal Effect of oral_anticoagulant
       if (data$oral_anticoagulant==1) {testnew11 = data
       testnew11$oral_anticoagulant[testnew11$oral_anticoagulant=='1']<-'0'
       oral_anticoagulantNew<-predict(model,testnew11,type="prob")[,2]
       oral_anticoagulantDep<-(oral_anticoagulantNew-pred)*100
       } else {testnew11 = data
       testnew11$oral_anticoagulant[testnew11$oral_anticoagulant=='0']<-'1'
       oral_anticoagulantNew<-predict(model,testnew11,type="prob")[,2]
       oral_anticoagulantDep<-(oral_anticoagulantNew-pred)*100}
       
       #Marginal Effect of DM
       if (data$DM==1) {testnew12 = data
       testnew12$DM[testnew12$DM=='1']<-'0'
       DMNew<-predict(model,testnew12,type="prob")[,2]
       DMDep<-(DMNew-pred)*100
       } else {testnew12 = data
       testnew12$DM[testnew12$DM=='0']<-'1'
       DMNew<-predict(model,testnew12,type="prob")[,2]
       DMDep<-(DMNew-pred)*100}
       
       #Marginal Effect of COPD
       if (data$COPD==1) {testnew13 = data
       testnew13$COPD[testnew13$COPD=='1']<-'0'
       COPDNew<-predict(model,testnew13,type="prob")[,2]
       COPDDep<-(COPDNew-pred)*100
       } else {testnew13 = data
       testnew13$COPD[testnew13$COPD=='0']<-'1'
       COPDNew<-predict(model,testnew13,type="prob")[,2]
       COPDDep<-(COPDNew-pred)*100}
       
       #Marginal Effect of CRF
       if (data$CRF==1) {testnew14 = data
       testnew14$CRF[testnew14$CRF=='1']<-'0'
       CRFNew<-predict(model,testnew14,type="prob")[,2]
       CRFDep<-(CRFNew-pred)*100
       } else {testnew14 = data
       testnew14$CRF[testnew14$CRF=='0']<-'1'
       CRFNew<-predict(model,testnew14,type="prob")[,2]
       CRFDep<-(CRFNew-pred)*100}
       
       #Marginal Effect of LC
       if (data$LC==1) {testnew15 = data
       testnew15$LC[testnew15$LC=='1']<-'0'
       LCNew<-predict(model,testnew15,type="prob")[,2]
       LCDep<-(LCNew-pred)*100
       } else {testnew15 = data
       testnew15$LC[testnew15$LC=='0']<-'1'
       LCNew<-predict(model,testnew15,type="prob")[,2]
       LCDep<-(LCNew-pred)*100}
       
       #Marginal Effect of Immunesuppresion
       if (data$Immunesuppresion==1) {testnew16 = data
       testnew16$Immunesuppresion[testnew16$Immunesuppresion=='1']<-'0'
       ImmunesuppresionNew<-predict(model,testnew16,type="prob")[,2]
       ImmunesuppresionDep<-(ImmunesuppresionNew-pred)*100
       } else {testnew16 = data
       testnew16$Immunesuppresion[testnew16$Immunesuppresion=='0']<-'1'
       ImmunesuppresionNew<-predict(model,testnew16,type="prob")[,2]
       ImmunesuppresionDep<-(ImmunesuppresionNew-pred)*100}
       
       #Marginal Effect of malignancy
       if (data$malignancy==1) {testnew17 = data
       testnew17$malignancy[testnew17$malignancy=='1']<-'0'
       malignancyNew<-predict(model,testnew17,type="prob")[,2]
       malignancyDep<-(malignancyNew-pred)*100
       } else {testnew17 = data
       testnew17$malignancy[testnew17$malignancy=='0']<-'1'
       malignancyNew<-predict(model,testnew17,type="prob")[,2]
       malignancyDep<-(malignancyNew-pred)*100}
       
       #Marginal Effect of RA
       if (data$RA==1) {testnew18 = data
       testnew18$RA[testnew18$RA=='1']<-'0'
       RANew<-predict(model,testnew18,type="prob")[,2]
       RADep<-(RANew-pred)*100
       } else {testnew18 = data
       testnew18$RA[testnew18$RA=='0']<-'1'
       RANew<-predict(model,testnew18,type="prob")[,2]
       RADep<-(RANew-pred)*100}
       
       #Marginal Effect of Pacemaker_ICD
       if (data$Pacemaker_ICD==1) {testnew19 = data
       testnew19$Pacemaker_ICD[testnew19$Pacemaker_ICD=='1']<-'0'
       Pacemaker_ICDNew<-predict(model,testnew19,type="prob")[,2]
       Pacemaker_ICDDep<-(Pacemaker_ICDNew-pred)*100
       } else {testnew19 = data
       testnew19$Pacemaker_ICD[testnew19$Pacemaker_ICD=='0']<-'1'
       Pacemaker_ICDNew<-predict(model,testnew19,type="prob")[,2]
       Pacemaker_ICDDep<-(Pacemaker_ICDNew-pred)*100}
       
       #Marginal Effect of days_to_DAIR
       if (data$days_to_DAIR!=0) {testnew20=data
       testnew20$days_to_DAIR<-0
       days_to_DAIRNew<-predict(model,testnew20,type="prob")[,2]
       days_to_DAIRDep<-(days_to_DAIRNew-pred)*100
       } else {days_to_DAIRDep<-0}
       
       #Marginal Effect of Indication_prosthesis
       if (data$Indication_prosthesis==2) {testnew21 = data
       testnew21$Indication_prosthesis[testnew21$Indication_prosthesis=='2']<-'1'
       Indication_prosthesisNew<-predict(model,testnew21,type="prob")[,2]
       Indication_prosthesisDep<-(Indication_prosthesisNew-pred)*100
       } else {testnew21 = data
       testnew21$Indication_prosthesis[testnew21$Indication_prosthesis=='1']<-'2'
       Indication_prosthesisNew<-predict(model,testnew21,type="prob")[,2]
       Indication_prosthesisDep<-(Indication_prosthesisNew-pred)*100}
       
       #Marginal Effect of index_revision
       if (data$index_revision==1) {testnew22 = data
       testnew22$index_revision[testnew22$index_revision=='1']<-'0'
       index_revisionNew<-predict(model,testnew22,type="prob")[,2]
       index_revisionDep<-(index_revisionNew-pred)*100
       } else {testnew22 = data
       testnew22$index_revision[testnew22$index_revision=='0']<-'1'
       index_revisionNew<-predict(model,testnew22,type="prob")[,2]
       index_revisionDep<-(index_revisionNew-pred)*100}
       
       #Marginal Effect of Cement
       if (data$Cement==1) {testnew23 = data
       testnew23$Cement[testnew23$Cement=='1']<-'0'
       CementNew<-predict(model,testnew23,type="prob")[,2]
       CementDep<-(CementNew-pred)*100
       } else {testnew23 = data
       testnew23$Cement[testnew23$Cement=='0']<-'1'
       CementNew<-predict(model,testnew23,type="prob")[,2]
       CementDep<-(CementNew-pred)*100}
       
       #Marginal Effect of Joint
       if (data$Joint==2) {testnew24 = data
       testnew24$Joint[testnew24$Joint=='2']<-'1'
       JointNew<-predict(model,testnew24,type="prob")[,2]
       JointDep<-(JointNew-pred)*100
       } else {testnew24 = data
       testnew24$Joint[testnew24$Joint=='1']<-'2'
       JointNew<-predict(model,testnew24,type="prob")[,2]
       JointDep<-(JointNew-pred)*100}
       
       #Marginal Effect of Wound_leakage
       if (data$Wound_leakage==1) {testnew25 = data
       testnew25$Wound_leakage[testnew25$Wound_leakage=='1']<-'0'
       Wound_leakageNew<-predict(model,testnew25,type="prob")[,2]
       Wound_leakageDep<-(Wound_leakageNew-pred)*100
       } else {testnew25 = data
       testnew25$Wound_leakage[testnew25$Wound_leakage=='0']<-'1'
       Wound_leakageNew<-predict(model,testnew25,type="prob")[,2]
       Wound_leakageDep<-(Wound_leakageNew-pred)*100}
       
       #Marginal Effect of Necrosis
       if (data$Necrosis==1) {testnew26 = data
       testnew26$Necrosis[testnew26$Necrosis=='1']<-'0'
       NecrosisNew<-predict(model,testnew26,type="prob")[,2]
       NecrosisDep<-(NecrosisNew-pred)*100
       } else {testnew26 = data
       testnew26$Necrosis[testnew26$Necrosis=='0']<-'1'
       NecrosisNew<-predict(model,testnew26,type="prob")[,2]
       NecrosisDep<-(NecrosisNew-pred)*100}
       
       #Marginal Effect of Fistula
       if (data$Fistula==1) {testnew27 = data
       testnew27$Fistula[testnew27$Fistula=='1']<-'0'
       FistulaNew<-predict(model,testnew27,type="prob")[,2]
       FistulaDep<-(FistulaNew-pred)*100
       } else {testnew27 = data
       testnew27$Fistula[testnew27$Fistula=='0']<-'1'
       FistulaNew<-predict(model,testnew27,type="prob")[,2]
       FistulaDep<-(FistulaNew-pred)*100}
       
       #Marginal Effect of Last_CRP
       if (data$Last_CRP!=1.8) {testnew28=data
       testnew28$Last_CRP<-1.8
       Last_CRPNew<-predict(model,testnew28,type="prob")[,2]
       Last_CRPDep<-(Last_CRPNew-pred)*100
       } else {Last_CRPDep<-0}
       
       #Marginal Effect of Last_leucocytes
       if (data$Last_leucocytes!=12.9) {testnew29=data
       testnew29$Last_leucocytes<-12.9
       Last_leucocytesNew<-predict(model,testnew29,type="prob")[,2]
       Last_leucocytesDep<-(Last_leucocytesNew-pred)*100
       } else {Last_leucocytesDep<-0}
       
       #Marginal Effect of Fever38
       if (data$Fever38==1) {testnew30 = data
       testnew30$Fever38[testnew27$Fever38=='1']<-'0'
       Fever38New<-predict(model,testnew30,type="prob")[,2]
       Fever38Dep<-(Fever38New-pred)*100
       } else {testnew30 = data
       testnew30$Fever38[testnew30$Fever38=='0']<-'1'
       Fever38New<-predict(model,testnew30,type="prob")[,2]
       Fever38Dep<-(Fever38New-pred)*100}
       
       #Marginal Effect of Positive_bloodcultures
       if (data$Positive_bloodcultures==1) {testnew31 = data
       testnew31$Positive_bloodcultures[testnew31$Positive_bloodcultures=='1']<-'0'
       Positive_bloodculturesNew<-predict(model,testnew31,type="prob")[,2]
       Positive_bloodculturesDep<-(Positive_bloodculturesNew-pred)*100
       } else {testnew31 = data
       testnew31$Positive_bloodcultures[testnew31$Positive_bloodcultures=='0']<-'1'
       Positive_bloodculturesNew<-predict(model,testnew31,type="prob")[,2]
       Positive_bloodculturesDep<-(Positive_bloodculturesNew-pred)*100}
       
       #Marginal Effect of Skin_infection
       if (data$Skin_infection==1) {testnew32 = data
       testnew32$Skin_infection[testnew32$Skin_infection=='1']<-'0'
       Skin_infectionNew<-predict(model,testnew32,type="prob")[,2]
       Skin_infectionDep<-(Skin_infectionNew-pred)*100
       } else {testnew32 = data
       testnew32$Skin_infection[testnew32$Skin_infection=='0']<-'1'
       Skin_infectionNew<-predict(model,testnew32,type="prob")[,2]
       Skin_infectionDep<-(Skin_infectionNew-pred)*100}
       
       #Marginal Effect of Mobilexchange
       if (data$Mobilexchange==1) {testnew33 = data
       testnew33$Mobilexchange[testnew33$Mobilexchange=='1']<-'0'
       MobilexchangeNew<-predict(model,testnew33,type="prob")[,2]
       MobilexchangeDep<-(MobilexchangeNew-pred)*100
       } else {testnew33 = data
       testnew33$Mobilexchange[testnew33$Mobilexchange=='0']<-'1'
       MobilexchangeNew<-predict(model,testnew33,type="prob")[,2]
       MobilexchangeDep<-(MobilexchangeNew-pred)*100}
       
       #Marginal Effect of Polymicrob
       if (data$Polymicrob==1) {testnew34 = data
       testnew34$Polymicrob[testnew34$Polymicrob=='1']<-'0'
       PolymicrobNew<-predict(model,testnew34,type="prob")[,2]
       PolymicrobDep<-(PolymicrobNew-pred)*100
       } else {testnew34 = data
       testnew34$Polymicrob[testnew34$Polymicrob=='0']<-'1'
       PolymicrobNew<-predict(model,testnew34,type="prob")[,2]
       PolymicrobDep<-(PolymicrobNew-pred)*100}
       
       #Marginal Effect of STAU
       if (data$STAU==1) {testnew35 = data
       testnew35$STAU[testnew35$STAU=='1']<-'0'
       STAUNew<-predict(model,testnew35,type="prob")[,2]
       STAUDep<-(STAUNew-pred)*100
       } else {testnew35 = data
       testnew35$STAU[testnew35$STAU=='0']<-'1'
       STAUNew<-predict(model,testnew35,type="prob")[,2]
       STAUDep<-(STAUNew-pred)*100}
       
       #Marginal Effect of MRSA
       if (data$MRSA==1) {testnew36 = data
       testnew36$MRSA[testnew36$MRSA=='1']<-'0'
       MRSANew<-predict(model,testnew36,type="prob")[,2]
       MRSADep<-(MRSANew-pred)*100
       } else {testnew36 = data
       testnew36$MRSA[testnew36$MRSA=='0']<-'1'
       MRSANew<-predict(model,testnew36,type="prob")[,2]
       MRSADep<-(MRSANew-pred)*100}
       
       #Marginal Effect of Staphepi
       if (data$Staphepi==1) {testnew37 = data
       testnew37$Staphepi[testnew37$Staphepi=='1']<-'0'
       StaphepiNew<-predict(model,testnew37,type="prob")[,2]
       StaphepiDep<-(StaphepiNew-pred)*100
       } else {testnew37 = data
       testnew37$Staphepi[testnew37$Staphepi=='0']<-'1'
       StaphepiNew<-predict(model,testnew37,type="prob")[,2]
       StaphepiDep<-(StaphepiNew-pred)*100}
       
       #Marginal Effect of gramnegative
       if (data$gramnegative==1) {testnew38 = data
       testnew38$gramnegative[testnew38$gramnegative=='1']<-'0'
       gramnegativeNew<-predict(model,testnew38,type="prob")[,2]
       gramnegativeDep<-(gramnegativeNew-pred)*100
       } else {testnew38 = data
       testnew38$gramnegative[testnew38$gramnegative=='0']<-'1'
       gramnegativeNew<-predict(model,testnew38,type="prob")[,2]
       gramnegativeDep<-(gramnegativeNew-pred)*100}
       
       #Marginal Effect of Escherichia_coli
       if (data$Escherichia_coli==1) {testnew39 = data
       testnew39$Escherichia_coli[testnew39$Escherichia_coli=='1']<-'0'
       Escherichia_coliNew<-predict(model,testnew39,type="prob")[,2]
       Escherichia_coliDep<-(Escherichia_coliNew-pred)*100
       } else {testnew39 = data
       testnew39$Escherichia_coli[testnew39$Escherichia_coli=='0']<-'1'
       Escherichia_coliNew<-predict(model,testnew39,type="prob")[,2]
       Escherichia_coliDep<-(Escherichia_coliNew-pred)*100}
       
       #Marginal Effect of Enterobacter_spp
       if (data$Enterobacter_spp==1) {testnew40 = data
       testnew40$Enterobacter_spp[testnew40$Enterobacter_spp=='1']<-'0'
       Enterobacter_sppNew<-predict(model,testnew40,type="prob")[,2]
       Enterobacter_sppDep<-(Enterobacter_sppNew-pred)*100
       } else {testnew40 = data
       testnew40$Enterobacter_spp[testnew40$Enterobacter_spp=='0']<-'1'
       Enterobacter_sppNew<-predict(model,testnew40,type="prob")[,2]
       Enterobacter_sppDep<-(Enterobacter_sppNew-pred)*100}
       
       #Marginal Effect of Pseudomonas_aerugi0sa
       if (data$Pseudomonas_aerugi0sa==1) {testnew41 = data
       testnew41$Pseudomonas_aerugi0sa[testnew41$Pseudomonas_aerugi0sa=='1']<-'0'
       Pseudomonas_aerugi0saNew<-predict(model,testnew41,type="prob")[,2]
       Pseudomonas_aerugi0saDep<-(Pseudomonas_aerugi0saNew-pred)*100
       } else {testnew41 = data
       testnew41$Pseudomonas_aerugi0sa[testnew41$Pseudomonas_aerugi0sa=='0']<-'1'
       Pseudomonas_aerugi0saNew<-predict(model,testnew41,type="prob")[,2]
       Pseudomonas_aerugi0saDep<-(Pseudomonas_aerugi0saNew-pred)*100}
       
       #Marginal Effect of Proteus_spp
       if (data$Proteus_spp==1) {testnew42 = data
       testnew42$Proteus_spp[testnew42$Proteus_spp=='1']<-'0'
       Proteus_sppNew<-predict(model,testnew42,type="prob")[,2]
       Proteus_sppDep<-(Proteus_sppNew-pred)*100
       } else {testnew42 = data
       testnew42$Proteus_spp[testnew42$Proteus_spp=='0']<-'1'
       Proteus_sppNew<-predict(model,testnew42,type="prob")[,2]
       Proteus_sppDep<-(Proteus_sppNew-pred)*100}
       
       #Marginal Effect of Enterococcus_spp
       if (data$Enterococcus_spp==1) {testnew43 = data
       testnew43$Enterococcus_spp[testnew43$Enterococcus_spp=='1']<-'0'
       Enterococcus_sppNew<-predict(model,testnew43,type="prob")[,2]
       Enterococcus_sppDep<-(Enterococcus_sppNew-pred)*100
       } else {testnew43 = data
       testnew43$Enterococcus_spp[testnew43$Enterococcus_spp=='0']<-'1'
       Enterococcus_sppNew<-predict(model,testnew43,type="prob")[,2]
       Enterococcus_sppDep<-(Enterococcus_sppNew-pred)*100}
       
       #Marginal Effect of Streptococci_spp
       if (data$Streptococci_spp==1) {testnew44 = data
       testnew44$Streptococci_spp[testnew44$Streptococci_spp=='1']<-'0'
       Streptococci_sppNew<-predict(model,testnew44,type="prob")[,2]
       Streptococci_sppDep<-(Streptococci_sppNew-pred)*100
       } else {testnew44 = data
       testnew44$Streptococci_spp[testnew44$Streptococci_spp=='0']<-'1'
       Streptococci_sppNew<-predict(model,testnew44,type="prob")[,2]
       Streptococci_sppDep<-(Streptococci_sppNew-pred)*100}
       
       #Marginal Effect of Candida_spp
       if (data$Candida_spp==1) {testnew45 = data
       testnew45$Candida_spp[testnew45$Candida_spp=='1']<-'0'
       Candida_sppNew<-predict(model,testnew45,type="prob")[,2]
       Candida_sppDep<-(Candida_sppNew-pred)*100
       } else {testnew45 = data
       testnew45$Candida_spp[testnew45$Candida_spp=='0']<-'1'
       Candida_sppNew<-predict(model,testnew45,type="prob")[,2]
       Candida_sppDep<-(Candida_sppNew-pred)*100}
       
       #Marginal Effect of Dayssymptoms
       if (data$Dayssymptoms!=0) {testnew46=data
       testnew46$Dayssymptoms<-0
       DayssymptomsNew<-predict(model,testnew46,type="prob")[,2]
       DayssymptomsDep<-(DayssymptomsNew-pred)*100
       } else {DayssymptomsDep<-0}
       
       Risk<-c(late_infectionDep,MaleDep,AgeDep,BMIDep,SmokingDep,AlcoholDep,DementiaDep,HypertensionDep,IHDDep,HFDep,oral_anticoagulantDep,DMDep,COPDDep,CRFDep,LCDep,ImmunesuppresionDep,malignancyDep,RADep,Pacemaker_ICDDep,days_to_DAIRDep,Indication_prosthesisDep,index_revisionDep,CementDep,JointDep,Wound_leakageDep,NecrosisDep,FistulaDep,Last_CRPDep,Last_leucocytesDep,Fever38Dep,Positive_bloodculturesDep,Skin_infectionDep,MobilexchangeDep,PolymicrobDep,STAUDep,MRSADep,StaphepiDep,gramnegativeDep,Escherichia_coliDep,Enterobacter_sppDep,Pseudomonas_aerugi0saDep,Proteus_sppDep,Enterococcus_sppDep,Streptococci_sppDep,Candida_sppDep,DayssymptomsDep)
       Variable=c("Late<br>Infection","Gender","Age","BMI","Smoking","Alcohol<br>Use","Dementia","Hypertension","Dialysis","Heart<br>Failure","Anticoagulation","Diabetes","COPD","Chronic<br>Kidney Disease","Liver<br>Cirrhosis","Immunocompromised","Cancer","Rheumatoid<br>Arthritis","Pacemaker/ICD","Days to<br>DAIR","Indication","Index<br>Procedure","Cemented<br>Components","Joint","Wound<br>Leakage","Necrosis","Fistula","CRP Level","Leucocyte<br>Count","Fever","Blood<br>Cultures","Skin<br>Infection","Modular<br>Component Exchange","Polymicrobial","S. aureus","MRSA","S. epidermidis","Gram-<br>negative","E. coli","Enterobacter","P. aeruginosa","Proteus","Enterococcus","Streptococcus","Candida","Days of<br>Symptoms")
       Dep<-data.frame(Variable,Risk)
       DepOrder<-Dep[order(-Risk),]
       Dep10<-as.data.frame(DepOrder[1:10,],row.names=c("1","2","3","4","5","6","7","8","9","10"))
       x<-as.character(Dep10$Variable)
       plot_ly(x=Dep10$Risk,y=Dep10$Variable,type='bar',text=~paste(round(Dep10$Risk,2),"%"),textposition="auto",textfont=list(family="Helvetica Neue",color=toRGB("white")),orientation='h',marker = list(color = 'rgb(255,0,0)'))%>%layout(autosize=TRUE,plot_bgcolor = "rgba(0,0,0,1)",paper_bgcolor="rgba(0,0,0,1)",yaxis=list(family="Helvetica Neue",automargin=TRUE,zeroline=FALSE,showline=FALSE,color="white",title="",type="category",categoryorder="array",categoryarray=rev(Dep10$Variable)),xaxis=list(automargin=TRUE,showticklabels=FALSE, color="white",title=""))
       })
   
}
# Run the application 
shinyApp(ui = ui, server = server)
