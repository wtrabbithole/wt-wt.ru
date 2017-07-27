//
// Dirty Words checker.
//
// Usage:
// local filter = DirtyWords ();
// print ( filter.checkPhrase ( "Полный пиздец, почему то не работают блядские закрылки" ) );
//
// Result:
// "Полный ******, почему то не работают ******** закрылки"
//


// Collect language tables
root_ <- getroottable()
foreach (varName in [ "excludesdata", "excludescore", "foulcore", "fouldata", "badphrases", "badsegments" ])
{
  root_[varName] <- []
  foreach (lang in [ "Russian", "English", "Japanese" ])
  {
    local varLang = varName+lang
    if (!(varLang in root_))
      continue
    root_[varName].extend(root_[varLang])
    delete root_[varLang] // we don't need language specific var anymore
  }
}
delete root_


alphabet <-
{
  upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯABCDEFGHIJKLMNOPQRSTUVWXYZ",
  lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяabcdefghijklmnopqrstuvwxyz"
};


preparereplace <-
[
  {
    pattern = @"[\'\-\+\;\.\,\*\?\(\)]",
    replace = " "
  },
  {
    pattern = @"[\!\:\_]",
    replace = " "
  }
];


prepareex <- "(а[х]?)|(в)|([вмт]ы)|(д[ао])|(же)|(за)";


prepareword <-
[
  {
    pattern = "ё",
    replace = "е"
  },
  {
    pattern = @"&[Ee][Uu][Mm][Ll];",
    replace = "е"
  },
  {
    pattern = "&#203;",
    replace = "е"
  },
  {
    pattern = @"&[Cc][Ee][Nn][Tt];",
    replace = "с"
  },
  {
    pattern = "&#162;",
    replace = "с"
  },
  {
    pattern = "&#120;",
    replace = "х"
  },
  {
    pattern = "&#121;",
    replace = "у"
  },
  {
    pattern = @"\|\/\|",
    replace = "и"
  },
  {
    pattern = @"3[\.\,]14[\d]{0,}",
    replace = "пи"
  },
  {
    pattern = @"[\'\-\+\;\.\,\*\?\(\)]",
    replace = ""
  },
  {
    pattern = @"[\!\:\_]",
    replace = ""
  }
];


preparewordwhile <-
{
  pattern = @"(.)\\1\\1",
  replace = "\\1\\1"
}


class DirtyWords
{
  word   = null;
  status = null;


  // Checks that phrase is correct.
  function checkPhrase ( text )
  {
    local phrase = text;

    // In Asian languages, there is no spaces to separate words.
    foreach (pattern in ::badsegments)
    {
      local re = ::regexp2(pattern)
      if (re.match(phrase))
        phrase = re.replace(getMaskedWord(pattern), phrase)
    }

    local words = prepare ( phrase );

    if ( typeof words == "array" )
    {
      foreach ( w in words )
      {
        word = w;
        if ( ! checkWord () )
          phrase = ::regexp2(w).replace(getMaskedWord(w), phrase)
      }
    }

    return phrase;
  }

  function isPhrasePassing ( text )
  {
    local phrase = checkPhrase(text)
    return (text == phrase)
  }

  // Checks that one word is correct.
  function checkWord ()
  {
    prepareWord ();

    status = true;
    local fl = utf8 (word).slice ( 0, 1 );

    if ( status )
      checkRegexps ( foulcore, true );

    if ( status )
    {
      for ( local i = 0; i < fouldata.len(); i++ )
      {
        if ( fouldata[i].key == fl )
          checkRegexps ( fouldata[i].arr, true );
      }
    }

    if ( status )
      checkRegexps ( badphrases, true );

    if ( ! status )
      checkRegexps ( excludescore, false );

    if ( ! status )
    {
      for ( local i = 0; i < excludesdata.len (); i++ )
      {
        if ( excludesdata[i].key == fl )
        {
          checkRegexps ( excludesdata[i].arr, false );
        }
      }
    }

    return status;
  }


  function prepare ( text )
  {
    local phrase = text;
    local buffer = null;

    foreach ( p in preparereplace )
      phrase = regexp2 ( p.pattern ).replace ( p.replace, phrase );

    local words = split ( phrase, " " );

    if ( typeof words != "array" )
      return false;

    local ex = regexp2 ( prepareex );
    local out = [];

    foreach ( word in words )
    {
      if ( (word.len() < 3) && ! ex.match (word) )
      {
        buffer += word;
      }
      else
      {
        if ( buffer != null )
        {
          out.push ( buffer )
          buffer = null;
        }

        out.push ( word );
      }
    }

    if ( buffer != null )
      out.push ( buffer )

    return out;
  }


  function prepareWord ()
  {
    // convert to lower
    word = utf8 ( word ).strtr ( alphabet.upper, alphabet.lower );
    word = rstrip ( word );

    // replaces
    foreach ( p in prepareword )
      word = regexp2 ( p.pattern ).replace ( p.replace, word );

    local post = null;

    while ( word != post )
    {
      post = word;
      word = regexp2 ( preparewordwhile.pattern ).replace ( preparewordwhile.replace, word );
    }
  }


  function checkRegexps ( regexps, accuse )
  {
    if ( typeof regexps != "array" )
      return false;

    foreach ( reg in regexps )
    {
      local reg_exp;
      if ( typeof reg == "table" )
        reg_exp = reg.value;
      else
        reg_exp = reg

      if ( regexp2 ( reg_exp ).match ( word ) )
      {
        status = !accuse;
        break;
      }
    }
  }


  function getMaskedWord(word = " ")
  {
    local length = ::utf8(word).charCount()
    local res = ""
    for (local i = 0; i < length; i++)
      res += "*"
    return res
  }
}


::dirty_words_filter <- DirtyWords()
