
angular.module('gamEvolve.util.jstree', [])

    .directive('jstree', function(currentGame) {

        var dnd = {
            'drag_check' : function (data) {
                if(data.r.attr('rel') === 'processor') { // No dropping in processors
                    return false;
                }
                // For simplicity's sake, DnD is allowed only for adding processors INSIDE tree nodes
                return {
                    after : false,
                    before : false,
                    inside : true
                };
            },
            'drag_finish' : function (data) {
                var processorId = data.o.attributes['processor-id'].nodeValue;
                var path = data.r.data('path');
                var target = currentGame.getTreeNode(path);
                var source = {
                    processor: processorId,
                    params: { in: {}, out: {} }
                };
                target.children.unshift(source);
            }
        };

        var types = {
            'types' : {
                'switch' : {
                    'icon' : {
                        'image' : '/assets/images/switch.png'
                    }
                },
                'processor' : {
                    'valid_children' : [] // Processors are leafs in the tree
                }
            }
        };

        return {

            restrict: 'A',
            scope: { jstree: '=' },
            link: function (scope, element, attrs) {
                scope.$watch('jstree', function () {
                    $(element).jstree({
                        'json_data' : {
                            'data' : scope.jstree
                        },
                        'dnd' : dnd,
                        'types' : types,
                        'core': { html_titles: true },
                        'plugins' : [ 'themes', 'ui', 'json_data', 'dnd', 'types', 'wholerow', 'crrm' ]
                    });
                });
                var emitEditEvent = function(path) {
                    scope.$emit('editChipButtonClick', JSON.parse(path));
                };
                $(element).on('click', 'a[editChip]', function(eventObject) {
                    var clicked = $(eventObject.target);
                    if ( clicked.attr('editChip') ) {
                        emitEditEvent( clicked.attr('editChip') );
                    } else {
                        emitEditEvent( $(clicked.parent()[0]).attr('editChip') );
                    }
                });
                var emitRemoveEvent = function(path) {
                    scope.$emit('removeChipButtonClick', JSON.parse(path));
                };
                $(element).on('click', 'a[removeChip]', function(eventObject) {
                    var clicked = $(eventObject.target);
                    if ( clicked.attr('removeChip') ) {
                        emitRemoveEvent( clicked.attr('removeChip') );
                    } else {
                        emitRemoveEvent( $(clicked.parent()[0]).attr('removeChip') );
                    }
                });
            }
        };
    });