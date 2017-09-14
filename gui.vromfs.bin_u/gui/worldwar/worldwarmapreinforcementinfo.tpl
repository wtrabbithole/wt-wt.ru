activeText {
  id:t='label_commands'
  text:t='<<header>>'
  hideEmptyText:t='yes'
  mediumFont:t='yes'
  pos:t='50%pw-50%w, 1@framePadding'
  position:t='relative'
}

armyGroupsBlock {
  id:t='army_groups_block'
  pos:t='50%pw-50%w, 0.01@scrn_tgt'
  position:t='relative'
  height:t='fh'
  flow:t='h-flow'
  flow-align:t='center'

<<#armyGroup>>
  armyGroup {
    id:t='<<id>>'
    flow:t='vertical'
    tdiv {
      css-hier-invalidate:t='yes'
      <<#armyCountryImg>>
        img {
          id:t='img_country_army'
          iconType:t='medium_country'
          background-image:t='<<image>>'
        }
      <</armyCountryImg>>

      <<#showOwnerItem>>
        ownerArmyItem {
          pos:t='0.01@scrn_tgt, 50%ph-50%h'
          position:t='relative'
          css-hier-invalidate:t='yes'

          include "gui/worldWar/worldWarMapArmyItem"
        }
      <</showOwnerItem>>

      clanTag {
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        hideEmptyText:t='yes'
        text:t='<<clanTag>>'
      }

      textarea {
        id:t='text_army_description'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        hideEmptyText:t='yes'
        text:t='<<armyDescription>>'
      }
    }

    table {
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      <<@armyRows>>
    }

    tdiv {
      pos:t='50%pw-50%w, 1@framePadding'
      position:t='relative'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      include "gui/commonParts/shortUnitString"
    }

    tdiv {
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      include "gui/worldWar/worldWarMapArmyItem"
    }
  }
<</armyGroup>>
}
