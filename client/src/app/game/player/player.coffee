# TODO: these should be configurable
GAME_DIMENSIONS = [960, 540]
SCREENSHOT_DIMENSIONS = [240, 135]
ANIMATION_FRAME_COUNT = 30

# Cppies error messages from stepLoop() into log messages attached to a 'global' circuit
extendLogMessages = (result) ->
  if not result.errors then return result

  result.logMessages.global = for error in result.errors
    { 
      path: error.path
      level: RW.logLevels.ERROR
      message: [error.stage, error.message] 
    }
  return result

extendFrameResults = (result, memory, inputIoData) ->
  # Override memory, inputIoData, and log messages
  extendLogMessages(result) 
  if memory? then result.memory = memory
  if inputIoData? then result.inputIoData = inputIoData 
  return result

# Initialize the memory of each circuit
buildInitialMemoryData = (circuits) -> 
  circuitMetas = RW.listCircuitMeta(circuits)
  memoryData = {}
  for circuitMeta in circuitMetas
    memoryData[circuitMeta.id] = RW.cloneData(circuits[circuitMeta.type].memory)
  return memoryData

angular.module('gamEvolve.game.player', [])
.controller "PlayerCtrl", ($scope, $location, games, currentGame, gameHistory, gameTime, overlay, gamePlayerState, RequestScreenshotEvent, RequestRecordAnimationEvent) -> 
  # Globals
  puppetIsAlive = false
  gameCode = null
  oldRoundedScale = null
  currentLocalVersion = null

  # Bring services into the scope
  $scope.currentGame = currentGame
  $scope.gameTime = gameTime
  $scope.gameHistoryMeta = gameHistory.meta
  $scope.gamePlayerState = gamePlayerState
  lastGameVersion = -1

  # The recorded screenshots (set to [] before each screenshot process)
  screenshots = []
  # The number of screenshots attempted (set to 1 for a single screenshot or ANIMATION_FRAME_COUNT for an animation)
  targetScreenshotCount = null

  windowEventListener = (e) -> 
    # Sandboxed iframes which lack the 'allow-same-origin' header have "null" rather than a valid origin. 
    if e.origin isnt "null" or e.source isnt $("#gamePlayer")[0].contentWindow then return

    message = e.data

    if message.type is "error"
      console.error("Puppet reported error on operation #{message.operation}.", message.error)
    else
      console.log("Puppet reported success on operation #{message.operation}.", message)

    switch message.operation
      when "areYouAlive"
        if message.type is "error" then throw new Error("Cannot deal with areYouAlive error message")
        puppetIsAlive = true
        onResize() # Resize might already have been sent
        sendLocation() # This will not change, even when new code is loaded 
      when "updateLocation"
        onUpdateCode() # Code might be already there 
      when "loadGameCode"
        if message.type is "error"
          $scope.$apply ->
            gameHistory.data.compilationErrors = [message.error]
            overlay.makeNotification("error")
            lastGameVersion = ++gameHistory.meta.version
        else
          # The game loaded successfully
          $scope.$apply ->
            gameHistory.data.compilationErrors = []
            lastGameVersion = ++gameHistory.meta.version

          updateFrames()
      when "recordFrame"
        if message.type is "error" then throw new Error("Cannot deal with recordFrame error message")

        $scope.$apply ->
          # Set the first frame
          initialMemoryData = buildInitialMemoryData(gameCode.circuits)
          newFrame = extendFrameResults(message.value, initialMemoryData)

          if message.value.errors
            console.error("Record frames errors", message.value.errors)
            overlay.makeNotification("error")

          gameHistory.data.frames = [newFrame]
          lastGameVersion = ++gameHistory.meta.version
          gameTime.currentFrameNumber = 0
      when "recording"
        if message.type isnt "error" then new Error("Cannot deal with recording success message")

        console.log("Recording met with error. Stopping it")
        $scope.$apply ->
          hadRecordingErrors = true # Used to notify the user 
          gameTime.isPlaying = false
      when "stopRecording" 
        $scope.$apply ->
          metError = false

          # Remove frames after the current one
          gameHistory.data.frames.length = gameTime.currentFrameNumber + 1

          # Calculate memory going into the next frame
          lastFrame = gameHistory.data.frames[gameTime.currentFrameNumber]
          lastMemory = RW.applyPatchesInCircuits(lastFrame.memoryPatches, lastFrame.memory)

          # Add in the new results
          for results in message.value
            gameHistory.data.frames.push(extendFrameResults(results, lastMemory))
              
            if results.errors 
              console.error("Stop recording frames errors", results.errors)
              metError = true
              break

            # Calcuate the next memory to be used
            lastMemory = RW.applyPatchesInCircuits(results.memoryPatches, lastMemory)

          if metError 
            overlay.makeNotification("error")
          else
            overlay.clearNotification() # Clear "updating" status

          # Go the the last frame
          gameTime.currentFrameNumber = gameHistory.data.frames.length - 1

          # Update the version
          lastGameVersion = ++gameHistory.meta.version
      when "playing"
        if message.type isnt "error" then new Error("Cannot deal with playing success message")

        console.log("Playing met with error. Stopping it")
        $scope.$apply ->
          hadRecordingErrors = true # Used to notify the user 
          gameTime.isPlaying = false
      when "stopPlaying" 
        $scope.$apply ->
          metError = false

          # Remove frames including the current one
          gameHistory.data.frames.length = gameTime.currentFrameNumber + 1

          # Calculate memory going into the next frame
          lastFrame = gameHistory.data.frames[gameTime.currentFrameNumber]

          results = message.value
          gameHistory.data.frames.push(extendFrameResults(results))
            
          if results.errors 
            console.error("Stop recording frames errors", results.errors)
            overlay.makeNotification("error")
          else
            overlay.clearNotification() # Clear "updating" status

          # Go the the last frame
          gameTime.currentFrameNumber = gameHistory.data.frames.length - 1

          # Update the version
          lastGameVersion = ++gameHistory.meta.version
      when "updateFrames" 
        if message.type is "error" then throw new Error("Cannot deal with updateFrames error")

        $scope.$apply ->
          metError = false

          # Replace existing frames by the new results, until an error is found
          lastMemory = gameHistory.data.frames[gameTime.currentFrameNumber].memory
          for index, results of message.value
            # Copy over old inputIoData
            frameIndex = gameTime.currentFrameNumber + parseInt(index)
            gameHistory.data.frames[frameIndex] = extendFrameResults(results, lastMemory, gameHistory.data.frames[frameIndex].inputIoData)

            if results.errors 
              console.error("Update frames errors", results.errors)
              metError = true
              break # Stop updating when error is found

            # Calcuate the next memory to be used
            lastMemory = RW.applyPatchesInCircuits(results.memoryPatches, lastMemory)

          if metError 
            overlay.makeNotification("error")
          else
            overlay.clearNotification() # Clear "updating" status

          # Update the version
          lastGameVersion = ++gameHistory.meta.version
          # Display the current frame
          # TODO: go to the frame of first error
          onUpdateFrame(gameTime.currentFrameNumber)

      when "takeScreenshot"
        screenshots.push(message.value.screenshot)

        if screenshots.length is targetScreenshotCount
          $scope.$apply -> completeTakeScreenshot()
    return 

  window.addEventListener("message", windowEventListener) 
  $scope.$on("$destroy", -> window.removeEventListener("message", windowEventListener))

  updateFrames = ->
    # Don't bother updating if we're playing right now
    if gameTime.isPlaying then return

    if gameHistory.data.frames.length > 0 and gameHistory.data.frames[0].inputIoData
      # Notify the user
      overlay.makeNotification("updating", true)

      # If there are already frames, then update them starting with the current frame
      inputIoDataFrames = _.pluck(gameHistory.data.frames[gameTime.currentFrameNumber..], "inputIoData")

      # If there are new circuits added, create memory and IO data for them
      frameMemory = gameHistory.data.frames[gameTime.currentFrameNumber].memory
      circuitMetas = RW.listCircuitMeta(gameCode.circuits)
      oldCircuitIds = _.keys(frameMemory)
      circuitIds = _.pluck(circuitMetas, "id")
      for newCircuitId in _.difference(circuitIds, oldCircuitIds)
        frameMemory[newCircuitId] = RW.cloneData(gameCode.circuits[_.findWhere(circuitMetas, { id: newCircuitId }).type].memory)
        for inputIoDataFrame in inputIoDataFrames
          inputIoDataFrame[newCircuitId] = inputIoDataFrame.global

      # The memory stored in the current frame
      sendMessage("updateFrames", { memory: frameMemory, inputIoDataFrames })
    else
      # Else just record the first frame
      initialMemoryData = buildInitialMemoryData(gameCode.circuits)
      sendMessage("recordFrame", { memory: initialMemoryData })

  sendMessage = (operation, value) ->  
    # Note that we're sending the message to "*", rather than some specific origin. 
    # Sandboxed iframes which lack the 'allow-same-origin' header don't have an origin which you can target: you'll have to send to any origin, which might alow some esoteric attacks. 
    console.log("Sending #{operation} message to puppet");
    $('#gamePlayer')[0].contentWindow.postMessage({operation: operation, value: value}, '*')

  # Call onUpdateCode() when the code changes 
  onUpdateCode = ->
    if not currentGame.version? then return
    if not puppetIsAlive then return
    if currentLocalVersion is currentGame.localVersion then return

    # Include the standard library in the game code
    gameCode = RW.cloneData(currentGame.version)
    for key, value of currentGame.standardLibrary
      _.defaults(gameCode[key], value)

    # Keep track of localVersion to avoid unneeded updates 
    currentLocalVersion = currentGame.localVersion
    console.log("Game code changed to version", currentLocalVersion)

    sendMessage("loadGameCode", gameCode)

  $scope.$watch("currentGame.localVersion", onUpdateCode, true)

  # Call onUpdateGode() if the game history changes 
  onUpdateGameHistory = ->
    if not currentGame.version? then return
    if not puppetIsAlive then return

    # To check that we haven't updated the game version ourselves
    if gameHistory.meta.version isnt lastGameVersion
      updateFrames()
  $scope.$watch('gameHistoryMeta.version', onUpdateGameHistory, true)

  onResize = -> 
    if not puppetIsAlive then return

    screenElement = $('#gamePlayer')
    scale = Math.min(screenElement.parent().outerWidth() / GAME_DIMENSIONS[0], screenElement.parent().outerHeight() / GAME_DIMENSIONS[1])
    roundedScale = scale.toFixed(2)
    # Avoid rescaling if not needed
    if oldRoundedScale is roundedScale then return 

    oldRoundedScale = roundedScale
    newSize = [
      roundedScale * GAME_DIMENSIONS[0]
      roundedScale * GAME_DIMENSIONS[1]
    ]
    remainingSpace = [
      screenElement.parent().outerWidth() - newSize[0]
      screenElement.parent().outerHeight() - newSize[1]
    ]
    screenElement.css 
      "width": "#{newSize[0]}px"
      "height": "#{newSize[1]}px"
      "left": "#{remainingSpace[0] / 2}px"
      "top": "#{remainingSpace[1] / 2}px"
    sendMessage("changeScale", roundedScale)

  onUpdateFrame = (frameNumber) ->
    if not gameCode? then return
    frameResult = gameHistory.data.frames[frameNumber]
    outputIoData = RW.applyPatchesInCircuits(frameResult.ioPatches, _.omit(frameResult.inputIoData, "global"))
    sendMessage("playBackFrame", { outputIoData: outputIoData })
  $scope.$watch('gameTime.currentFrameNumber', onUpdateFrame, true)

  onUpdatePlaying = ->
    if not gameCode? then return
    if gameTime.isPlaying 
      if gameTime.currentFrameNumber < gameHistory.data.frames.length
        # Start playing on next frame (assumes recordFrame() has been done in editor)
        lastFrame = gameHistory.data.frames[gameTime.currentFrameNumber]
        nextMemory = RW.applyPatchesInCircuits(lastFrame.memoryPatches, lastFrame.memory)
      else
        # Just start with initial memory (like in play-only mode)
        nextMemory = buildInitialMemoryData(gameCode.circuits)

      if gameTime.inRecordMode
        # Notify the user
        overlay.makeNotification("recording")
        sendMessage("startRecording", { memory: nextMemory })
      else
        # Notify the user
        overlay.makeNotification("playing")
        sendMessage("startPlaying", { memory: nextMemory })
    else
      if gameTime.inRecordMode
        # Notify the user
        overlay.makeNotification("updating", true) # This could take a while...
        sendMessage("stopRecording")
      else 
        sendMessage("stopPlaying")
  $scope.$watch('gameTime.isPlaying', onUpdatePlaying, true)

  onChangeVolume = ->
    sendMessage("changeVolume", gamePlayerState.volume)

  $scope.$watch('gamePlayerState.volume', onChangeVolume, true)

  onMuteVolume = ->
    sendMessage("muteVolume", gamePlayerState.isMuted)

  $scope.$watch('gamePlayerState.isMuted', onMuteVolume, true)

  # Keep pinging puppet until he responds
  checkPuppetForSignsOfLife = -> 
    if puppetIsAlive then return # Will be set to true by message event listener

    sendMessage("areYouAlive")
    setTimeout(checkPuppetForSignsOfLife, 500)

  checkPuppetForSignsOfLife()

  sendLocation = ->
    locationInfo = 
      url: $location.absUrl()
      protocol: $location.protocol()
      host: $location.host()
      port: $location.port()
      path: $location.path()
      query: $location.search()
      hash: $location.hash()

    sendMessage("updateLocation", locationInfo)

  takeScreenshot = -> 
    screenshots = []
    targetScreenshotCount = 1
    gameTime.isTakingScreenshots = true
    sendMessage("takeScreenshot", { size: SCREENSHOT_DIMENSIONS, index: 0 })

  unsubscribeToRequestScreenshot = RequestScreenshotEvent.listen(takeScreenshot)
  $scope.$on("$destroy", unsubscribeToRequestScreenshot)

  recordAnimation = ->
    screenshots = []
    targetScreenshotCount = ANIMATION_FRAME_COUNT
    gameTime.isTakingScreenshots = true

    # Count the number of frames reminaing (including current frame)
    remainingFrames = gameHistory.data.frames.length - gameTime.currentFrameNumber
    # Divide the number of frames by the target number
    animationSpeed = remainingFrames / ANIMATION_FRAME_COUNT

    for i in [0...ANIMATION_FRAME_COUNT]
      frameNumber = Math.floor(gameTime.currentFrameNumber + i * animationSpeed)

      frameResult = gameHistory.data.frames[frameNumber]
      outputIoData = RW.applyPatchesInCircuits(frameResult.ioPatches, _.omit(frameResult.inputIoData, "global"))
      sendMessage("playBackFrame", { outputIoData: outputIoData })

      sendMessage("takeScreenshot", { size: SCREENSHOT_DIMENSIONS, index: i })

  completeTakeScreenshot = ->
    if targetScreenshotCount is 1 
      currentGame.version.screenshot = screenshots[0]
      currentGame.updateLocalVersion()
    else 
      gifShotOptions = 
        images: screenshots
        gifWidth: SCREENSHOT_DIMENSIONS[0]
        gifHeight: SCREENSHOT_DIMENSIONS[1]

      gifshot.createGIF gifShotOptions, (obj) ->
        if obj.error then return console.error(error)

        currentGame.version.animation = obj.image
        currentGame.updateLocalVersion()

    gameTime.isTakingScreenshots = false

  unsubscribeToRequestRecordAnimation = RequestRecordAnimationEvent.listen(recordAnimation)
  $scope.$on("$destroy", unsubscribeToRequestRecordAnimation)


  # TODO: need some kind of notification from flexy-layout when a block changes size!
  # Until then automatically resize once in a while.
  resizeIntervalId = setInterval(onResize, 1000)
  $scope.$on("$destroy", -> clearInterval(resizeIntervalId))
