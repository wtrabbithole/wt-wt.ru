tdiv {
  id:t='common_armies_block'
  width:t='pw'
  flow:t='vertical'

  activeText {
    id:t='label_army'
    text:t='#worldWar/armyStrength'
    mediumFont:t='yes'
    pos:t='50%pw-50%w, 1@framePadding'
    position:t='relative'
  }

  <<#side>>
  tdiv {
    width:t='50%pw'
    pos:t='0, 0'
    position:t='relative'
    flow:t='vertical'

    <<#countryImg>>
    img {
      iconType:t='medium_country'
      background-image:t='<<countryImg>>'
      position:t='relative'
      pos:t='50%pw-50%w, 0';
    }
    <</countryImg>>

    <<#armiesList>>
      include "gui/commonParts/shortUnitString"
    <</armiesList>>
  }
  <</side>>
  tdiv {
    width:t='pw'
    pos:t='0, 0'
    position:t='relative'
    padding:t='0, 1@framePadding'
    tdiv {
      width:t='50%pw'
      flow:t='vertical'
      img {
        id:t='img_country_side_1'
        iconType:t='medium_country'
        background-image:t=''
        position:t='relative'
        pos:t='50%pw-50%w, 0';
      }
      table {
        id:t='table_army_side_1'
        pos:t='50%pw-50%w, 0.01@scrn_tgt'
        position:t='relative'
      }
    }
    tdiv {
      width:t='50%pw'
      flow:t='vertical'
      img {
        id:t='img_country_side_2'
        iconType:t='medium_country'
        background-image:t=''
        position:t='relative'
        pos:t='50%pw-50%w, 0';
      }
      table {
        id:t='table_army_side_2'
        pos:t='50%pw-50%w, 0.01@scrn_tgt'
        position:t='relative'
      }
    }
  }
}
