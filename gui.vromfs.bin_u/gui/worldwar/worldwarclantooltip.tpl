frame {
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
    tinyFont:t='yes'
  }

  textareaNoTab {
    text:t='<<?clan/memberListTitle>> (<<getMembersCountText>>)'
    tinyFont:t='yes'
  }

  <<#canShowActivity>>
  tdiv {
    tinyFont:t='yes'
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
}
