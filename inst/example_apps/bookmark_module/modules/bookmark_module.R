library(shiny)
library(dplyr)
library(lubridate)

bookmark_modal_save_ui <- function(id) {
  ns <- NS(id)

  tagList(
    actionLink(ns("show_save_modal"), "Save session")
  )
}

bookmark_modal_load_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    actionLink(ns("show_load_modal"), "Restore session")
  )
}

bookmark_load_ui <- function(id) {
  ns <- NS(id)
  tagList(
    uiOutput(ns("saved_sessions"))
  )  
}

bookmark_mod <- function(input, output, session, storage) {
  ns <- session$ns
  session_df <- reactive({
    req(storage$bmi_storage$reader())
    storage$bmi_storage$reader()
  })
  
  output$saved_sessions_placeholder <- renderUI({
    fluidRow(
      DT::dataTableOutput(session$ns("saved_sessions_table")),
      uiOutput(ns("saved_sessions"))
    )
  })
  
  output$saved_sessions_table <- DT::renderDataTable({
    req(session_df())
    DT::datatable(
      session_df(),
      escape = FALSE,
      selection = "single"
    )
  })

  output$saved_sessions <- renderUI({
    df <- session_df()

    radioButtons(
      ns("session_choice"),
      "Choose Session",
      choices = df$url
      # choiceNames = df$save_name,
      # choiceValues = df$url
    )
  })

  observeEvent(input$restore, {
    req(input$session_choice)
    storage$restore(input$session_choice)
  })
  
  shiny::setBookmarkExclude(c("show_save_modal", "show_load_modal", "save_name", "save", "session_choice", "restore"))
  
  observeEvent(input$show_load_modal, {
    showModal(modalDialog(size = "xl", easyClose = TRUE, title = "Restore session",
      footer = tagList(
        modalButton("Cancel"),
        actionButton(session$ns("restore"), "Restore", class = "btn-primary")
      ),
      uiOutput(session$ns("saved_sessions_placeholder"))
    ))
  })
  
  observeEvent(input$show_save_modal, {
    showModal(modalDialog(easyClose = TRUE,
      textInput(session$ns("save_name"), "Give this session a name"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton(session$ns("save"), "Save", class = "btn-primary")
      )
    ))
  })
  
  observeEvent(input$save, ignoreInit = TRUE, {
    tryCatch(
      {
        if (!isTruthy(input$save_name)) {
          stop("Please specify a bookmark name")
        } else {
          removeModal()
          #storage$snapshot(save_name = input$save_name)
          storage$snapshot(
            #session_metadata = NULL
            session_metadata = list(
              save_name = input$save_name,
              timestamp = Sys.time()
            )
          )
          showNotification(
            "Session successfully saved"
          )
        }
      },
      error = function(e) {
        showNotification(
          conditionMessage(e),
          type = "error"
        )
      }
    )
  })
}



### Utility functions ==============

friendly_time <- function(t) {
  t <- round_date(t, "seconds")
  now <- round_date(Sys.time(), "seconds")

  abs_day_diff <- abs(day(now) - day(t))
  age <- now - t
  
  abs_age <- abs(age)
  future <- age != abs_age
  dir <- ifelse(future, "from now", "ago")
  
  
  format_rel <- function(singular, plural = paste0(singular, "s")) {
    x <- as.integer(round(time_length(abs_age, singular)))
    sprintf("%d %s %s",
      x,
      ifelse(x == 1, singular, plural),
      dir
    )
  }
  
  ifelse(abs_age == seconds(0), "Now",
    ifelse(abs_age < minutes(1), format_rel("second"),
      ifelse(abs_age < hours(1), format_rel("minute"),
        ifelse(abs_age < hours(6), format_rel("hour"),
          # Less than 24 hours, and during the same calendar day
          ifelse(abs_age < days(1) & abs_day_diff == 0, strftime(t, "%I:%M:%S %p"),
            ifelse(abs_age < days(3), strftime(t, "%a %I:%M:%S %p"),
              strftime(t, "%Y/%m/%d %I:%M:%S %p")
            ))))))
}
