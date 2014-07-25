# These properties need to be converted from JSON strings to objects upon loading, and back to JSON for saving
JSON_PROPERTIES = [
  "circuits"
  "processors"
  "switches"
  "transformers"
  "assets"
]

META_PROPERTIES = [
  "name"
]

angular.module('gamEvolve.util.gameConverter', [])

.factory "gameConverter", ->
  convertGameVersionFromEmbeddedJson: (gameVersionJson) ->
    gameVersion = 
      id: gameVersionJson.id
      gameId: gameVersionJson.gameId
      versionNumber: gameVersionJson.versionNumber
      fileVersion: gameVersionJson.fileVersion
    for propertyName in JSON_PROPERTIES
      gameVersion[propertyName] = JSON.parse(gameVersionJson[propertyName])
    return gameVersion

  convertGameVersionToEmbeddedJson: (gameVersion) ->
    gameVersionJson = 
      id: gameVersion.id
      gameId: gameVersion.gameId
      versionNumber: gameVersion.versionNumber
      fileVersion: gameVersion.fileVersion
    for propertyName in JSON_PROPERTIES
      gameVersionJson[propertyName] = JSON.stringify(gameVersion[propertyName], null, 2)
    return gameVersionJson

  convertGameFromJson: (gameJson) ->
    parsed = JSON.parse(gameJson)
    return {
       info: _.pick(parsed, META_PROPERTIES...)
       version: _.pick(parsed, JSON_PROPERTIES...)
    }

  convertGameToJson: (currentGame) ->    
    filteredObject = _.extend({}, _.pick(currentGame.info, META_PROPERTIES...), _.pick(currentGame.version, JSON_PROPERTIES...))
    return JSON.stringify(filteredObject, null, 2)

  removeHashKeys: (node) ->
    if "$$hashKey" of node then delete node["$$hashKey"]
    for key, value of node
      if _.isObject(value) then @removeHashKeys(value)
    return node

  bringGameUpToDate: (gameCode) ->
    # Add sound
    if gameCode.fileVersion < 0.3
      for circuitType, circuit of gameCode.circuits
        if "channels" not of circuit.io then circuit.io.channels = []
    gameCode.fileVersion = 0.3
    return gameCode
