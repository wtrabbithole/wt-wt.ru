tdiv {
  flow:t='vertical'

  <<#isLoading>>
    textareaNoTab {
      left:t='50%(pw-w)'
      position:t='relative'
      text:t='#loading'
    }
    animated_wait_icon {
      left:t='50%(pw-w)'
      position:t='relative'
      background-rotation:t='0'
    }
  <</isLoading>>

  <<^isLoading>>
    tdiv {
      activeText {
        text:t='#clan/clan_type/<<getTypeName>>'
        caption:t='yes'
      }

      activeText {
        text:t=' <<tag>> <<name>>'
        caption:t='yes'
      }
    }

    textareaNoTab {
      text:t='<<?clan/creationDate>> <<getCreationDateText>>'
      smallFont:t='yes'
    }

    textareaNoTab {
      text:t='<<?clan/memberListTitle>> (<<getMembersCountText>>)'
      smallFont:t='yes'
    }

    <<#canShowActivity>>
    tdiv {
      smallFont:t='yes'
      textareaNoTab {
        text:t='<<?clan/squadron_rating>> '
      }
      textareaNoTab {
        id:t='clan_activity_value';
        text:t='<<getActivity>>';
        overlayTextColor:t='userlog'
      }
    }
    <</canShowActivity>>
  <</isLoading>>
}
