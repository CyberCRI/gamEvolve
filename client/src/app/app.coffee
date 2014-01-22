# Let's keep this list in alphabetical order
angular.module( 'gamEvolve', [
  'templates-app'
  'templates-common'
  'ui.bootstrap'
  'ui.router'
  'ui.state'
  'ui.ace'
  'gamEvolve.model.games'
  'gamEvolve.model.users'
  'gamEvolve.util.logger'
  'gamEvolve.util.tree'
  'gamEvolve.util.boardConverter'
  'gamEvolve.game'
  'gamEvolve.game.actions'
  'gamEvolve.game.assets'
  'gamEvolve.game.edit'
  'gamEvolve.game.layers'
  'gamEvolve.game.log'
  'gamEvolve.game.player'
  'gamEvolve.game.select'
  'gamEvolve.game.switches'
  'gamEvolve.game.time'  
  'gamEvolve.game.tools'
  'gamEvolve.model.games'
  'gamEvolve.model.history'
  'gamEvolve.model.time'
  'gamEvolve.model.users'
  'gamEvolve.util.logger'
  'xeditable'
])

.config( ( $stateProvider, $urlRouterProvider ) ->
  $urlRouterProvider.otherwise( '/game/1234/edit' )
)

.controller('AppCtrl', ( $scope, $location ) ->
  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | gameEvolve'
)

# Set options for xeditable
.run (editableOptions) ->
  editableOptions.theme = "bs2"

