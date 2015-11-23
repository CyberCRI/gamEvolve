angular.module('gamEvolve.game.list', ["ui.bootstrap.pagination"])

.config ($stateProvider) ->
    $stateProvider.state 'game-list',
      url: '/game/list?&page'
      views:
        "main":
          controller: 'GameListCtrl'
          templateUrl: 'game/list/gameList.tpl.html'
      data:
        pageTitle: 'List Games'

.controller 'GameListCtrl', ($scope, games, loggedUser, ChangedLoginEvent, users) ->
    # Sort games by reverse chronological order
    timeSorter = (game) -> -1 * new Date(game.lastUpdatedTime).valueOf()

    # Sort games by likes
    likeSorter = (game) -> return -1 * game.likedData.likedCount

    $scope.recommendations = []

    $scope.isLoggedIn = -> loggedUser.isLoggedIn()
 
    ###
    $scope.gamesPerPage = 3 * 3
    $scope.gameCount = 100 # Will be replaced with request

    $scope.allGames = []
    $scope.myGames = []
    $scope.page = 1
    ###

    ###
    # Keep track of last page so not to repeat the same request 
    lastRequestedPage = null

    loadAllGamesPage = ->
      # Don't bother repeating the same request
      if lastRequestedPage == $scope.page then return
      lastRequestedPage = $scope.page

      games.loadPage($scope.page, $scope.gamesPerPage).then (allGames) ->
        $scope.allGames = allGames      
    $scope.$watch("page", loadAllGamesPage)

    loadGames = ->
      makeRequests = ->
        if loggedUser.isLoggedIn() 
          games.getMyGames().then (myGames) ->
            $scope.myGames = _.sortBy(myGames, timeSorter)

        games.countItems().then (gameCount) -> $scope.gameCount = gameCount

        loadAllGamesPage()

        games.getRecommendations().then (recommendations) -> $scope.gameRecommendations = recommendations

      # First try to log user in before getting game lists
      if loggedUser.isLoggedIn() then makeRequests()
      else users.restoreSession().then(makeRequests)

    loadGames()
    unsubscribeChangedLoginEvent = ChangedLoginEvent.listen(loadGames)

    ###

    ###
        if loggedUser.isLoggedIn()
      query.ownerId = 
        $ne: loggedUser.profile.id 
    ###

    ### 
          $sort: 
        $lastUpdatedTime: -1
    ###
    $scope.countAllGames = -> games.countGames()
    $scope.getPageOfAllGames = (pageNumber, gamesPerPage) -> games.getPageOfGames(pageNumber, gamesPerPage)

    $scope.countMyGames = -> games.countGames
      ownerId: loggedUser.profile.id 
    $scope.getPageOfMyGames = (pageNumber, gamesPerPage) -> games.getPageOfGames pageNumber, gamesPerPage, 
      ownerId: loggedUser.profile.id 

    # $scope.$on("destroy", unsubscribeChangedLoginEvent)
