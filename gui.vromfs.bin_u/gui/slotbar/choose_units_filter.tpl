<<#rows>>
options_list {
  flow:t='vertical';
  text {
    text:t='<<option_title>>';
  }
  options_nest {
    MultiSelect {
      id:t='<<option_id>>';
      uid:t='<<option_uid>>';
      idx:t='<<option_idx>>';
      value:t='<<option_value>>';
      on_select:t='onSelectedOptionChooseUnit';
      flow:t='horizontal';
      tinyFont:t='yes';
      optionsShortcuts:t='yes';
      <<#nums>>
      multiOption {
        filter_multi_option:t='yes';
        textarea {
          text:t='<<option_name>>';
          text-align:t='center';
          input-transparent:t='yes';
        }
        <<^visible>>
        display:t='hide';
        inactive:t='yes';
        <</visible>>
        CheckBoxImg{}
      }
      <</nums>>
    }
  }
}
<</rows>>