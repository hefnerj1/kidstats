shinyServer(function(input, output, session) {
  # get the reference data from the selectize input
  refdata <- reactive({
    if (length(input$refsamp) == 0) return()
    switch(input$refsamp,
           "za" = salb_za,
           NULL)
  })

  # construct elements input table
  el_names <- c("<h4>Elements</h4>", "<h5>Femur</h5>", "<h5>Tibia</h5>", "<h5>Humerus</h5>", "<h5>Radius</h5>", "<h5>Ulna</h5>")
  el_meas <- c("Diaphyseal Length", "Proximal Breadth", "Midshaft Breadth", "Distal Breadth")
  dl <- c("Diaphyseal Length",
    "<input id='fdl' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='tdl' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='hdl' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='rdl' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='udl' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>"
  )
  pb <- c("Proximal Breadth",
    NA,
    "<input id='tpb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='hpb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='rpb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    NA
  )
  msb <- c("Midshaft Breadth",
    "<input id='fmsb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='tmsb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='hmsb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='rmsb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='umsb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>"
  )
  db <- c("Distal Breadth",
    "<input id='fdb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='tdb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='hdb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    "<input id='rdb' class='shiny-bound-input' type='number' value='NA' min='0' max='500'>",
    NA
  )
  # render elements input table
  output$el_table <- renderTable({
    data.frame(el_names, dl, pb, msb, db)
  }, sanitize.text.function = function(x) x, sanitize.rownames.function = function(x) x, sanitize.colnames.function = function(x) x, include.rownames = FALSE, include.colnames = FALSE)

  # elements is the newdata data.frame
  elements <- reactive({
    elements <- c()
    elements <- c(elements, "FDL" = input$fdl)
    elements <- c(elements, "FMSB" = input$fmsb)
    elements <- c(elements, "FDB" = input$fdb)
    elements <- c(elements, "TDL" = input$tdl)
    elements <- c(elements, "TPB" = input$tpb)
    elements <- c(elements, "TMSB" = input$tmsb)
    elements <- c(elements, "TDB" = input$tdb)
    elements <- c(elements, "HDL" = input$hdl)
    elements <- c(elements, "HPB" = input$hpb)
    elements <- c(elements, "HMSB" = input$hmsb)
    elements <- c(elements, "HDB" = input$hdb)
    elements <- c(elements, "RDL" = input$rdl)
    elements <- c(elements, "RPB" = input$rpb)
    elements <- c(elements, "RMSB" = input$rmsb)
    elements <- c(elements, "RDB" = input$rdb)
    elements <- c(elements, "UDL" = input$udl)
    elements <- c(elements, "UMSB" = input$umsb)
    elements <- data.frame(as.list(elements))
    elements <- elements[, which(!is.na(elements[1,])), drop = FALSE]
    if (length(elements) == 0) return()
    return(elements)
  })

  # render exclude lists
  # change values for ex_age and ex_sex
   observe({
     opts <- c()
     if (!is.null(elements())) opts <- names(elements())
     updateSelectInput(session, "ex_age", choices = opts)
     updateSelectInput(session, "ex_sex", choices = opts)
   })

  # create the reference data from the raw data
  refsamp <- reactive({
    if (is.null(refdata()) || is.null(elements())) return()
    ref <- dplyr::select_(refdata(), .dots = c("ID", "SEX", "AGE", names(elements())))
    return(ref)
  })

  age_samp <- reactive({
    if (is.null(refsamp())) return()
    samp <- dplyr::select_(refsamp(), .dots = c("-ID", "-SEX"))
    if (length(input$ex_age) != 0) {
      ex <- paste0("-", input$ex_age)
      samp <- na.omit(dplyr::select_(samp, .dots = ex))
    } else {samp <- na.omit(samp)}
    if (length(samp) == 1) return()
    return(samp)
  })

  sex_samp <- reactive({
    if (is.null(refsamp())) return()
    samp <- dplyr::select_(refsamp(), .dots = c("-ID", "-AGE"))
    if (length(input$ex_sex) != 0) {
      ex <- paste0("-", input$ex_sex)
      samp <- na.omit(dplyr::select_(samp, .dots = ex))
    } else {samp <- na.omit(samp)}
    if (length(samp) == 1) return()
    return(samp)
  })

############################## UTILITY FUNCTIONS ##############################

  boot_accuracy_fda <- function(data, indices, formula, priors = c(.4, .6)){
    d <- data[indices,]
    leftout <- setdiff(seq(along = indices), indices)
    if (length(leftout) > 0) dtest <- data[leftout,] else dtest <- d
    fit <- mda::fda(formula, keep.fitted = TRUE, method = earth, keepxy = TRUE, data = d)
    ct.all <- mda::confusion(predict(fit, newdata = dtest, prior = priors), dtest$SEX)
    diagonal <- diag(prop.table(ct.all, 1))
    s <- sum(diag(prop.table(ct.all)))
    result <- c(diagonal, s)
    return(result)
  }

#################################### MODEL ####################################

  # create the models and predict age and sex using newdata
  earth_mod <- eventReactive(input$evaluate_age, {
    if (is.null(age_samp())) return()
    withProgress(message = "Estimating age", value = 0, {
      incProgress(0.1, detail = "Retrieving reference data")
      earth_data <- age_samp()
      # transform age
      incProgress(0.1, detail = "Transforming AGE")
      earth_data$AGE <- switch(input$transform,
        sqrt = sqrt(earth_data$AGE),
        cbrt = (earth_data$AGE) ^ (1/3),
        earth_data$AGE
      )
      # create formula
      incProgress(0.1, detail = "Creating formula")
      earth_formula <- as.formula('AGE ~ .')
      # create age model and make predictions
      incProgress(0.3, detail = "Creating Earth model")
      model_age <- earth::earth(earth_formula, data = earth_data, varmod.method = "lm", ncross = 30, nfold = 10)
      incProgress(0.3, detail = "Predicting age")
      estage <- predict(model_age, newdata = elements(), interval = "pint")
      # undo AGE transform
      incProgress(0.1, detail = "Undoing Age transformation")
      estage <- switch(input$transform,
        sqrt = round(estage ^ 2, digits = 2),
        cbrt = round(estage ^ 3, digits = 2),
        round(estage, digits = 2)
      )
      setProgress(1)
    })
    return(list(model_age, estage))
  })

  fda_mod <- eventReactive(input$evaluate_sex, {
    if (is.null(sex_samp())) return()
    withProgress(message = "Estimating sex", value = 0, {
      incProgress(0.1, detail = "Retrieving reference data")
      fda_data <- sex_samp()
      # create formula
      incProgress(0.1, detail = "Creating formula")
      fda_formula <- as.formula('SEX ~ .')
      # create sex model
      incProgress(0.2, detail = "Creating FDA model")
      model_sex <- mda::fda(fda_formula, data = fda_data, method = earth, keep.fitted = TRUE, keepxy = TRUE)
      # predict sex
      incProgress(0.3, detail = "Predicting sex")
      estsex <- data.frame(predict(model_sex, newdata = elements(), type = "posterior"))
      # confusion matrix
      incProgress(0.1, detail = "Calculating confusion matrix")
      cm <- mda::confusion(predict(model_sex, prior = c(1/2, 1/2)), fda_data$SEX)
      # classification table
      incProgress(0.1, detail = "Calculating classification table")
      ct <- diag(prop.table(cm, 1))
      # classification accuracy
      incProgress(0.1, detail = "Calculating classification accuracy")
      if (input$bstrap_ca) {
        fda_ca <- boot::boot(data = fda_data, statistic = boot_accuracy_fda, formula = fda_formula, strata = fda_data$SEX, R = 1000)
        bs <- TRUE
      } else {
        fda_ca <- sum(diag(prop.table(cm)))
        bs <- FALSE
      }
      setProgress(1)
    })
    # return model and sex estimation
    return(list(model_sex, estsex, fda_ca, bs, cm, ct))
  })


############################# OUTPUT ##########################################

#  # output the reference data in the reference sample section of the ui
#  output$table <- DT::renderDataTable({
#    if (is.null(refsamp())) return(NULL)
#    DT::datatable(refsamp(), rownames = FALSE, options = list(pageLength = 50))
#  })

  # output earth model predictions
  output$earth_pred <- renderPrint({
    if (is.null(earth_mod())) return()
    # if (is.null(earth_mod()) || is.null(elements())) return()
    pred <- earth_mod()[[2]]
    pred <- pred[, c(2, 1, 3)]
    return(pred)
  })
  # output sample size used in model
  output$earth_samp <- renderPrint({
    if (is.null(earth_mod())) return()
    sampsize <- nrow(age_samp())
    message <- paste0("Sample size used in model: ", sampsize)
    return(message)
  })
  # output earth model summary
  output$earth_summary <- renderPrint({
    if (is.null(earth_mod())) return()
    # if (input$evaluate_age == 0) return()
    summary(earth_mod()[[1]])
  })
  # output earth model variable importance
  output$earth_varimp <- renderPrint({
    if (is.null(earth_mod())) return()
    # if (input$evaluate_age == 0) return()
    caret::varImp(earth_mod()[[1]])
  })
  # output earth model selection plot
  output$earth_modsel <- renderPlot({
    if (is.null(earth_mod())) return()
    plot(earth_mod()[[1]], which = 1)
  })
  # output earth qq plot
  output$earth_qq <- renderPlot({
    if (is.null(earth_mod())) return()
    plot(earth_mod()[[1]], which = 4)
  })
  # output earth rvf plot
  output$earth_rvf <- renderPlot({
    if (is.null(earth_mod())) return()
    plot(earth_mod()[[1]], which = 3, level = .95, info = TRUE)
  })
  output$hide_ageout <- reactive({
    if (is.null(earth_mod())) TRUE else FALSE
  })
  outputOptions(output, 'hide_ageout', suspendWhenHidden = FALSE)

  # output sex model predictions
  output$fda_pred <- renderPrint({
    if (is.null(fda_mod())) return()
    fda_mod()[[2]]
  })
  # output sample size used in model
   output$fda_samp <- renderPrint({
     if (is.null(fda_mod())) return()
     sampsize <- nrow(sex_samp())
     message <- paste0("Sample size used in model: ", sampsize)
     return(message)
   })
  # output fda coefficients
  output$fda_coef <- renderPrint({
    if (is.null(fda_mod())) return()
    coef(fda_mod()[[1]])
  })
  # output fda model variable importance
  output$fda_varimp <- renderPrint({
    if (is.null(fda_mod())) return()
    caret::varImp(fda_mod()[[1]])
  })
  # output fda confusion matrix
  output$fda_confusion <- renderPrint({
    if (is.null(fda_mod())) return()
    fda_mod()[[5]]
  })
  # output classification table
  output$fda_ct <- renderPrint({
    if (is.null(fda_mod())) return()
    fda_mod()[[6]]
  })
  # output bootstraped classification accuracy
  output$fda_ca <- renderPrint({
    if (is.null(fda_mod())) return()
    fda_mod()[[3]]
  })
  output$fda_ca_title <- renderText({
    if (is.null(fda_mod())) return()
    if (fda_mod()[[4]] == TRUE) return(paste0(h4("Bootstrapped Classification Accuracy")))
    return(paste0(h4("Classification Accuracy")))
  })
  output$fda_bca_plot <- renderPlot({
    if (fda_mod()[[4]] == FALSE || is.null(fda_mod())) return()
    plot(fda_mod()[[3]])
  })
  output$hide_sexout <- reactive({
    if (is.null(fda_mod())) TRUE else FALSE
  })
  outputOptions(output, 'hide_sexout', suspendWhenHidden = FALSE)

################################ QUICK OUTPUT ############################

 # output the estage value for quick output
 output$age <- renderText({
   if (input$evaluate_age == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(earth_mod())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   estage <- earth_mod()[[2]][1]
   message <- paste(h5("Estimated age:"), h3(sprintf("%.2f", estage)), sep = " ")
   return(message)
 })
 # output lwr PI for quick output
 output$lwr <- renderText({
   if (input$evaluate_age == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(earth_mod())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   lwr <- earth_mod()[[2]][2]
   message <- paste(h5("Lower PI:"), h3(sprintf("%.2f", lwr)), sep = " ")
   return(message)
 })
 # output upr PI for quick output
 output$upr <- renderText({
   if (input$evaluate_age == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(earth_mod())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   upr <- earth_mod()[[2]][3]
   message <- paste(h5("Upper PI:"), h3(sprintf("%.2f", upr)), sep = " ")
   return(message)
 })
 # output gRsq for quick output
 output$rsq <- renderText({
   if (input$evaluate_age == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(earth_mod())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   rsq <- round(earth_mod()[[1]]$grsq, digits = 4)
   message <- paste(h5("Model R^2:"), h3(sprintf("%.4f", rsq)), sep = " ")
   return(message)
 })
 # output age sample size for quick output
 output$sampsize <- renderText({
   if (input$evaluate_age == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(age_samp())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   samp <- nrow(age_samp())
   message <- paste(h5("Sample size:"), h3(samp), sep = " ")
   return(message)
 })

 # output sex sample size for quick output
 output$sampsize_sex <- renderText({
   if (input$evaluate_sex == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(sex_samp())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   samp <- nrow(sex_samp())
   message <- paste(h5("Sample size:"), h3(samp), sep = " ")
   return(message)
 })
 # output sex posterior F
 output$pred_f <- renderText({
   if (input$evaluate_sex == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(fda_mod())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   post_f <- round(fda_mod()[[2]]$F, digits = 4)
   message <- paste(h5("Posterior Female:"), h3(sprintf("%.4f", post_f)), sep = " ")
   return(message)
 })
 # output sex posterior M
 output$pred_m <- renderText({
   if (input$evaluate_sex == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(fda_mod())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   post_m <- round(fda_mod()[[2]]$M, digits = 4)
   message <- paste(h5("Posterior Male:"), h3(sprintf("%.4f", post_m)), sep = " ")
   return(message)
 })
 output$qca <- renderText({
   if (input$evaluate_sex == 0) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   if (is.null(fda_mod())) return(paste0("<i class = 'fa fa-circle-thin fa-2x' style = 'padding-top: 25px; color: #DDD;'></i>"))
   input$evaluate_sex
   isolate({
     qca <- if (input$bstrap_ca) round(fda_mod()[[3]]$t0, digits = 4) else round(fda_mod()[[3]], digits = 4)
     message <- paste(h5("Classification Accuracy:"), h3(sprintf("%.4f", qca)), sep = " ")
     return(message)
   })
 })

 # age report download handler
 output$downloadReport_age <- downloadHandler(
   filename = function() {
     paste('KS_age_report', sep = '.', switch(
       # input$format, PDF = 'pdf', HTML = 'html', Word = 'docx'
       input$format, HTML = 'html', Word = 'docx'
     ))
   },

   content = function(file) {
     src <- system.file('ksapp/www/md/report_age.Rmd', package = 'kidstats')

     # temporarily switch to the temp dir, in case you do not have write
     # permission to the current working directory
     owd <- setwd(tempdir())
     on.exit(setwd(owd))
     file.copy(src, 'report_age.Rmd')

     out <- rmarkdown::render('report_age.Rmd', switch(
       input$format,
       PDF = rmarkdown::pdf_document(), HTML = rmarkdown::html_document(css = system.file('ksapp/www/css/report.css', package = 'kidstats')), Word = rmarkdown::word_document()
     ))
     file.rename(out, file)
   }
 )

 # sex report download handler
 output$downloadReport_sex <- downloadHandler(
   filename = function() {
     paste('KS_sex_report', sep = '.', switch(
       # input$format, PDF = 'pdf', HTML = 'html', Word = 'docx'
       input$format, HTML = 'html', Word = 'docx'
     ))
   },

   content = function(file) {
     src <- system.file('ksapp/www/md/report_sex.Rmd', package = 'kidstats')

     # temporarily switch to the temp dir, in case you do not have write
     # permission to the current working directory
     owd <- setwd(tempdir())
     on.exit(setwd(owd))
     file.copy(src, 'report_sex.Rmd')

     out <- rmarkdown::render('report_sex.Rmd', switch(
       input$format,
       PDF = rmarkdown::pdf_document(), HTML = rmarkdown::html_document(css = system.file('ksapp/www/css/report.css', package = 'kidstats')), Word = rmarkdown::word_document()
     ))
     file.rename(out, file)
   }
 )

 session$onSessionEnded(function(){stopApp("Thank you for using KidStats.")})

})
