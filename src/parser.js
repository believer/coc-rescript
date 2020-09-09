let parseLocation = (location) => {
  if (location.includes('-')) {
    let [from, to] = location.split('-')
    let [fromLine, fromChar] = from.split(':')
    let isSingleLine = to.includes(':')
    let [toLine, toChar] = isSingleLine ? to.split(':') : [fromLine, to]

    return {
      start: {
        line: parseInt(fromLine) - 1,
        character: parseInt(fromChar) - 1,
      },
      end: { line: parseInt(toLine) - 1, character: parseInt(toChar) },
    }
  } else {
    let [line, char] = location.split(':')
    let end = { line: parseInt(line) - 1, character: parseInt(char) }

    return {
      start: { ...end, character: end.character - 1 },
      end,
    }
  }
}

let parseError = (fileErr) => {
  let res = []
  let lines = fileErr.split('\n')
  let severity = [
    "  We've found a bug for you!",
    '  Warning number',
    '  Syntax error!',
  ]

  for (let i = 0; i < lines.length; i++) {
    var line = lines[i]

    if (severity.includes(line)) {
      res.push([])
    } else if (/(^ {2,}[0-9]+)|(^ {3,})/.test(line)) {
      // code display. Swallow
    } else if (line.startsWith('  ')) {
      res[res.length - 1].push(line)
    }
  }

  return res.map((r) => {
    let [fileAndLocation, ...message] = r
    let [, location] = fileAndLocation.trim().split(' ')

    return {
      range: parseLocation(location),
      message: message
        .filter((msg) => msg.trim())
        .map((msg) => msg.trim())
        .join('\n'),
      severity: 1,
      source: 'rescript',
    }
  })
}

module.exports = parseError
