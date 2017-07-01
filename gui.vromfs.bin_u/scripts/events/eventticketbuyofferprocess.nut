::g_event_ticket_buy_offer <- {

  // Holds process to prevent it
  // from being garbage collected.
  currentProcess = null
}

function g_event_ticket_buy_offer::offerTicket(event)
{
  ::dagor.assertf(currentProcess == null, "Attempt to use multiple event ticket but offer processes.");
  currentProcess = EventTicketBuyOfferProcess(event)
}

class EventTicketBuyOfferProcess
{
  _event = null
  _tickets = null

  constructor (event)
  {
    _event = event
    _tickets = ::events.getEventTickets(event, true)
    foreach (ticket in _tickets)
      ::g_item_limits.enqueueItem(ticket)
    if (::g_item_limits.requestLimits(true))
      ::add_event_listener("ItemLimitsUpdated", onEventItemLimitsUpdated, this)
    else
      handleTickets()
  }

  function onEventItemLimitsUpdated(params)
  {
    ::remove_event_listeners_by_env("ItemLimitsUpdated", this)
    handleTickets()
  }

  function handleTickets()
  {
    ::g_event_ticket_buy_offer.currentProcess = null

    // Array of tickets with valid limit data.
    local availableTickets = []
    foreach (ticket in _tickets)
      if (ticket.getLimitsCheckData().result)
        availableTickets.push(ticket)

    if (availableTickets.len() == 0)
    {
      local tournamentData = ::events.getEventActiveTicket(_event).getTicketTournamentData()
      local locParams = {
        timeleft = ::secondsToString(tournamentData.timeToWait)
      }
      ::scene_msg_box("cant_join", null, ::loc("events/wait_for_sessions_to_finish/main") + "\n" +
        ::loc("events/wait_for_sessions_to_finish/optional", locParams),
          [["ok", function() {}]], "ok")
    }
    else
    {
      local windowParams = {
        event = _event
        tickets = availableTickets
        activeTicket = getEventActiveTicket(_event)
      }
      ::gui_start_modal_wnd(::gui_handlers.TicketBuyWindow, windowParams)
    }
  }
}
