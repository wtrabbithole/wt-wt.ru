<<#rows>>
tr{
  id:t='tr_<<id>>'

  td {
    width:t='pw'
    cellType:t='top'
    overflow-x:t='hidden'
    optiontext {
      text:t ='<<name>>'
      padding-top:t='4'
    }
  }
  td {
    width:t='pw'
    height:t='@baseTrHeight'
    <<@option>>

    activeText {
      id:t='value_<<id>>'
      margin-left:t='0.01@sf'
    }
  }
}
<</rows>>
