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

    optionValueText {
      id:t='value_<<id>>'
    }
  }
}
<</rows>>
