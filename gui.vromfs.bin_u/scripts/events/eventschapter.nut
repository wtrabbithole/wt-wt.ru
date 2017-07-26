class EventChapter
{
  name = ""
  eventIds = []
  sortValid = true

  constructor(chapter_id)
  {
    name = chapter_id
    eventIds = []
    update()
  }

  function getLocName()
  {
    return ::loc("events/chapter/" + name)
  }

  function getEvents()
  {
    if (!sortValid)
    {
      sortValid = true
      eventIds.sort(sortChapterEvents)
    }
    return eventIds
  }

  function getEventsSortPrioritySumm()
  {
    local result = 0
    foreach (eventName in getEvents())
    {
      local event = ::events.getEvent(eventName)
      if(event)
        result += ::getTblValue("uiSortPriority", event, 0)
    }
    return result
  }

  function isEmpty()
  {
    return eventIds.len() == 0
  }

  function update()
  {
    eventIds = ::events.getEventsList(EVENT_TYPE.ANY, (@(name) function (event) {
      return ::events.getEventsChapter(event) == name
             && ::events.isEventVisibleInEventsWindow(event)
    })(name))
    sortValid = false
  }

  function sortChapterEvents(eventId1, eventId2)
  {
    local event1 = ::events.getEvent(eventId1)
    local event2 = ::events.getEvent(eventId2)
    if (event1 == null && event2 == null)
      return 0
    if ((event1 == null) != (event2 == null))
      return event1 == null ? -1 : 1
    local diffCode1 = ::events.getEventDiffCode(event1)
    local diffCode2 = ::events.getEventDiffCode(event2)
    if (diffCode1 != diffCode2)
      return diffCode1 > diffCode2 ? 1 : -1
    local eventName1 = ::english_russian_to_lower_case(::events.getEventNameText(event1))
    local eventName2 = ::english_russian_to_lower_case(::events.getEventNameText(event2))
    if (eventName1 != eventName2)
      return eventName1 > eventName2 ? 1 : -1
    return 0
  }
}

class EventChaptersManager
{
  chapters = []
  chapterDict = {}

  constructor()
  {
    chapters = []
    chapterDict = {}

    ::add_event_listener("GameLocalizationChanged", onEventGameLocalizationChanged, this)
  }

  /**
  * Method go through events list and gather chapters.
  * Then calls all chapters to update
  * And when some chapters are empty, removes them
  */
  function updateChapters()
  {
    local eventsList = ::events.getEventsList(EVENT_TYPE.ANY, ::events.isEventVisibleInEventsWindow)

    foreach (eventName in eventsList)
    {
      local event = ::events.getEvent(eventName)
      if (event == null)
        continue
      local chapterId = ::events.getEventsChapter(event)
      getChapter(chapterId) || addChapter(chapterId)
    }

    foreach (chapter in chapters)
      chapter.update()

    for (local i = chapters.len() - 1; i >= 0; i--)
      if (chapters[i].getEvents().len() == 0)
        deleteChapter(chapters[i].name)
  }

  function getChapter(chapter_name)
  {
    local chapterIndex = ::getTblValue(chapter_name, chapterDict, -1)
    return chapterIndex < 0 ? null : chapters[chapterIndex]
  }

  function addChapter(chapter_name)
  {
    chapters.append(EventChapter(chapter_name))
    chapterDict[chapter_name] <- chapters.len() - 1
  }

  function deleteChapter(chapter_name)
  {
    chapters.remove(chapterDict[chapter_name])
    chapterDict.rawdelete(chapter_name)
    updateChapterDict()
  }

  function updateChapterDict()
  {
    foreach (idx, event in chapters)
      chapterDict[event.name] = idx
  }

  function getChapters()
  {
    return chapters
  }

  function onEventGameLocalizationChanged(params)
  {
    foreach (chapter in chapters)
      chapter.sortValid = false
  }
}
