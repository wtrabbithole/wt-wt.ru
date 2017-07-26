<<#rows>>
tr {
  td {
    hr { class:t='bottom' }
    battleStateIco { id:t='battle-state-ico' class:t='' }
    <<#iconLeft>>
    icon {
      img { id:t='torpedo-ico' class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_torpedo' }
      img { id:t='rocket-ico'  class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_missile' }
      img { id:t='bomb-ico'    class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_bomb'  }
      img { id:t='unit-ico'    class:t='unit'   background-image:t=''  shopItemType:t='' }
    }
    <</iconLeft>>
    <<^iconLeft>>
    icon {
      img { id:t='unit-ico'    class:t='unit'   background-image:t=''  shopItemType:t='' }
      img { id:t='bomb-ico'    class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_bomb'  }
      img { id:t='rocket-ico'  class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_missile' }
      img { id:t='torpedo-ico' class:t='weapon' reloading:t='no' background-image:t='#ui/gameuiskin#weap_torpedo' }
    }
    <</iconLeft>>
    textareaNoTab {
      id:t='name'
      text:t=''
    }
    textareaNoTab {
      id:t='unit'
      text:t=''
    }
  }
}
<</rows>>
