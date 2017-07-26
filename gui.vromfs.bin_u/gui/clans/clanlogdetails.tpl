<<#role_old>>
tdiv {
  activeText {
    text:t='<<?clan/log/old_members_role>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/<<role_old>>'
  }
}
<</role_old>>
<<#role_new>>
tdiv {
  activeText {
    text:t='<<?clan/log/new_members_role>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/<<role_new>>'
  }
}
<</role_new>>
<<#name>>
tdiv {
  activeText {
    text:t='<<?clan/clan_name>><<?ui/colon>>'
  }
  activeText {
    text:t='<<name>>'
  }
}
<</name>>
<<#tag>>
tdiv {
  activeText {
    text:t='<<?clan/clan_tag>><<?ui/colon>>'
  }
  activeText {
    text:t='<<tag>>'
  }
}
<</tag>>
<<#slogan>>
tdiv {
  width:t='pw'
  textareaNoTab {
    width:t='pw'
    text:t='<<?clan/clan_slogan>><<?ui/colon>><<slogan>>'
  }
}
<</slogan>>
<<#region>>
tdiv {
  width:t='pw'
  activeText {
    text:t='<<?clan/clan_region>><<?ui/colon>>'
  }
  textareaNoTab {
    width:t='fw'
    text:t='<<region>>'
  }
}
<</region>>
<<#desc>>
tdiv {
  width:t='pw'
  textareaNoTab {
    width:t='pw'
    text:t='<color=@white><<?clan/clan_description>><<?ui/colon>></color><<desc>>'
  }
}
<</desc>>
<<#announcement>>
tdiv {
  width:t='pw'
  textareaNoTab {
    width:t='pw'
    text:t='<color=@white><<?clan/clan_announcement>><<?ui/colon>></color><<announcement>>'
  }
}
<</announcement>>
<<#type>>
tdiv {
  activeText{
    text:t='<<?clan/clan_type>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/clan_type/<<type>>'
  }
}
<</type>>
<<#status>>
tdiv {
  activeText {
    text:t='<<?caln/log/membership_applications>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/log/membership_applications/<<status>>'
  }
}
<</status>>
<<#signText>>
tdiv {
  position:t='relative'
  pos:t='pw - w, 0'

  activeText {
    text:t='<<signText>>'
  }
}
<</signText>>
<<#upgrade_members_old>>
tdiv {
  activeText {
    text:t='<<?clan/log/old_members_limit>><<?ui/colon>>'
  }
  activeText {
    text:t='<<upgrade_members_old>>'
  }
}
<</upgrade_members_old>>
<<#upgrade_members_new>>
tdiv {
  activeText {
    text:t='<<?clan/log/new_members_limit>><<?ui/colon>>'
  }
  activeText {
    text:t='<<upgrade_members_new>>'
  }
}
<</upgrade_members_new>>
