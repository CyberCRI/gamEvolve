
angular.module('gamEvolve.game.list', [])

.config ($stateProvider) ->
    $stateProvider.state 'game-list',
      url: '/game/list'
      views:
        "main":
          controller: 'GameListCtrl'
          templateUrl: 'game/list/gameList.tpl.html'
      data:
        pageTitle: 'List Games'

.controller 'GameListCtrl', ($scope, games, $state) ->

    $scope.games = games.loadAll()

    $scope.select = (game) ->
      $state.transitionTo('game-edit', {gameId: game.id})