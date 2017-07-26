invisSlider{
  id:t='<<desc>>';
  value:t='<<value>>';
  min:t='<<min>>';
  max:t='<<max>>';
  on_change_value:t='<<cb>>';
  size:t='1@sliderProgress_720p_width, 1@sliderProgress_720p_height';
  max-width:t='0.95pw - 2.5*@scrn_tgt/100.0';
  pos:t='2.5*@scrn_tgt/100.0 - 0.5@sliderThumbWidth, 50%ph-50%h';
  position:t='absolute';

  optionProgress{
    id:t='<<id>>_progress';
    width:t='pw-@sliderThumbWidth';
    pos:t='50%pw-50%w, 50%ph-50%h';
    position:t='absolute';
    type:t='old';
    value:t='<<value>>';
    style:t='min:<<min>>; max:<<max>>;';
  }

  invisSlider{
    id:t='<<id>>_thumb';
    value:t='<<value>>';
    size:t='pw, ph';
    min:t='<<min>>';
    max:t='<<max>>';
    pos:t='0, 0';
    position:t='absolute';
    on_change_value:t='passValueToParent';

    sliderButton{
      type:t='various';
      position:t='absolute';
      img{}
    }
  }

  sliderButton{
    type:t='various';
    position:t='absolute';
    img{
      style:t='size:0,0;'
    }
  }
}
