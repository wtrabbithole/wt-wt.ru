div {  //header
  id:t='<<id>>'
  size:t='sw, sh'
  position:t='root'
  <<#darkBlocks>>
    <<darkBlock>>
    {
      size:t='<<size0>>, <<size1>>'
      pos:t='<<pos0>>, <<pos1>>'
      position:t='absolute'
      <<#onClick>>
        behaviour:t='button'
        _on_click:t='<<onClick>>'
      <</onClick>>
    }
  <</darkBlocks>>
  <<#lightBlocks>>
    <<lightBlock>>
    {
      id:t='<<id>>'
      size:t='<<size0>>, <<size1>>'
      pos:t='<<pos0>>, <<pos1>>'
      position:t='absolute'
      <<#onClick>>
        behaviour:t='button'
        _on_click:t='<<onClick>>'
        <<#accessKey>>
          accessKey:t='<<accessKey>>'
        <</accessKey>>
      <</onClick>>
    }
  <</lightBlocks>>
}
