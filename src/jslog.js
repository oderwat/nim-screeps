// a helper...

function jslog() {
  var txt = ""
  for (var i = 0; i < arguments.length; i++) {
    if(i > 0
      && txt.substr(txt.length-1,1) != '>'
      && (typeof(arguments[i]) != 'string' ||
        arguments[i].substr(0,1) != '<' )) {
      txt += " "
    }
    txt += arguments[i]
  }
  console.log(txt)
}
