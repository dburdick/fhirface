'use strict'

BASE_URL = null
baseUrl = ()->
  BASE_URL || "#{window.location.protocol}//#{window.location.host}"

require('./fhir')

app = angular.module 'fhirface', [
  'ngCookies',
  'ngAnimate',
  'ngSanitize',
  'ngRoute',
  'ui.codemirror',
  'app-fhir',
  'ng-fhir'
], ($routeProvider) ->
    $routeProvider
      .when '/',
        templateUrl: '/views/conformance.html'
        controller: 'ConformanceCtrl'
      .when '/conformance',
        templateUrl: '/views/conformance.html'
        controller: 'ConformanceCtrl'
      .when '/resources/Any',
        templateUrl: '/views/resources/index.html'
        controller: 'IndexCtrl'
      .when '/resources/Any/history',
        templateUrl: '/views/resources/history.html'
        controller: 'HistoryCtrl'
      .when '/resources/Any/tags',
        templateUrl: '/views/resources/tags.html'
        controller: 'TagsCtrl'
      .when '/resources/Any/transaction',
        templateUrl: '/views/resources/transaction.html'
        controller: 'TransactionCtrl'
      .when '/resources/Any/document',
        templateUrl: '/views/resources/document.html'
        controller: 'DocumentCtrl'
      .when '/resources/:resourceType',
        templateUrl: '/views/resources/index.html'
        controller: 'ResourcesIndexCtrl'
      .when '/resources/:resourceType/history',
        templateUrl: '/views/resources/history.html'
        controller: 'ResourcesHistoryCtrl'
      .when '/resources/:resourceType/tags',
        templateUrl: '/views/resources/tags.html'
        controller: 'ResourcesTagsCtrl'
      .when '/resources/:resourceType/new',
        templateUrl: '/views/resources/new.html'
        controller: 'ResourcesNewCtrl'
      .when '/resources/:resourceType/:id',
        templateUrl: '/views/resources/show.html'
        controller: 'ResourceCtrl'
      .when '/resources/:resourceType/:id/history',
        templateUrl: '/views/resources/history.html'
        controller: 'ResourceHistoryCtrl'
      .when '/resources/:resourceType/:id/tags',
        templateUrl: '/views/resources/tags.html'
        controller: 'ResourceTagsCtrl'
      .otherwise
        redirectTo: '/'

require('./menu')

identity = (x)-> x

rm = (x, xs)-> xs.splice(xs.indexOf(x),1)

NOTIFICATION_REMOVE_TIMEOUT = 2000

magic = {
  active: 0
  notifications: []
  error: null
  removeNotification: (i)->
    magic.notifications.splice(magic.notifications.indexOf(i), 1)
}

app.run ($rootScope, $appFhir, menu)->
#  $rootScope.fhir = $appFhir
  magic = $appFhir
  $rootScope.fhir = magic
  $rootScope.menu = menu

app.config ($fhirProvider, $httpProvider)->
  $fhirProvider.baseUrl = baseUrl()
  $httpProvider.interceptors.push ($q, $timeout)->
    {
      request: (config) ->
        console.log("request ", config)
        note = angular.copy(config)
        unless note.url.match(/^\/views\//)
          note.status = "..."
          note.config = config
          magic.notifications.push(note)
          magic.active += 1
          $timeout (()-> magic.removeNotification(note)), NOTIFICATION_REMOVE_TIMEOUT
        config
      response: (response) ->
        console.log("responce: ", response)
        magic.active -= 1
        (magic.notifications.filter((n) -> n.config == response.config)[0] || {}).status = response.status
        response
      responseError: (rejection) ->
        console.log("error: ", rejection)
        magic.active -= 1
        (magic.notifications.filter((n) -> n.config == rejection.config)[0] || {}).status = rejection.status
        magic.error = rejection.data || "Server error #{rejection.status} while loading: #{rejection.config.url}"
        $q.reject(rejection)
    }
cropUuid = (id)->
  return "ups no uuid :(" unless id
  sid = id.substring(id.length - 6, id.length)
  "...#{sid}"

app.filter 'uuid', ()-> cropUuid

app.filter 'urlFor', ()->
  (res)->
    parts = res.id.split(/\//)
    id = parts[parts.length - 1]
    "#/resources/#{res.content.resourceType}/#{id}"

cropId = (id)->
  return "ups no uuid :(" unless id
  arr = id.split('/')
  arr[arr.length - 1]

app.filter 'id', ()-> cropId

keyComparator = (key)->
 (a, b) ->
   switch
     when a[key] < b[key] then -1
     when a[key] > b[key] then 1
     else 0

app.filter 'profileTypes', ()->
  (xs)->
    (xs || []).map((i)->
      if i.code == 'ResourceReference'
        i.profile.split('/').pop()
      else
        i.code
    ).join(', ')

app.controller 'ConformanceCtrl', (menu, $scope, $fhir) ->
  menu.build({}, 'conformance*')

  $fhir.conformance success: (data)->
    console.log('metadata', data)
    $scope.resources = [{type: 'Any'}].concat data.rest[0].resource.sort(keyComparator('type')) || []
    delete data.rest
    delete data.text
    $scope.conformance = data

app.controller 'IndexCtrl', (menu, $fhir, $appFhirParams, $appFhirSearch, $scope, $routeParams) ->
  menu.build($routeParams, 'conformance', 'index_all*', 'transaction', 'document', 'history_all', 'tags_all')

  rt = 'Alert'

  $scope.searchResourceType = rt
  $scope.searchState = 'search'
  $scope.searchFilter = ''
  $scope.query = {searchParam: []}

  $scope.addParam = (p)->
    if $scope.searchState == 'addSortParam'
      $scope.query.addSortParam(p)
    if $scope.searchState == 'addRef'
      $scope.query.addInclude(p)
    else
      $scope.query.addSearchParam(p)
      $scope.searchFilter = ''
    $scope.searchState="search"

  $fhir.profile type: rt, success: (data)->
    $scope.profile = data
    $scope.query = $appFhirParams(data)

  $scope.typeFilterSearchParams = (type, filter)->
    $appFhirSearch.typeFilterSearchParams(type, filter)

  $scope.search = ()->
    $fhir.search type: rt, query: {}, success: (data, s, x, config)->
      console.log(data)
      $scope.searchUri = config
      $scope.resources = data.entry || []

app.controller 'ResourcesIndexCtrl', (menu, $fhir, $appFhirParams, $appFhirSearch, $scope, $routeParams) ->
  menu.build($routeParams, 'conformance', 'index*', 'new', 'history_type', 'tags_type')

  rt = $routeParams.resourceType

  $scope.searchResourceType = rt
  $scope.searchState = 'search'
  $scope.searchFilter = ''
  $scope.query = {searchParam: []}

  $scope.addParam = (p)->
    if $scope.searchState == 'addSortParam'
      $scope.query.addSortParam(p)
    if $scope.searchState == 'addRef'
      $scope.query.addInclude(p)
    else
      $scope.query.addSearchParam(p)
      $scope.searchFilter = ''
    $scope.searchState="search"

  $fhir.profile type: rt, success: (data)->
    $scope.profile = data
    $scope.query = $appFhirParams(data)

  $scope.typeFilterSearchParams = (type, filter)->
    $appFhirSearch.typeFilterSearchParams(type, filter)

  $scope.search = ()->
    $fhir.search type: rt, query: {}, success: (data, s, x, config) ->
        $scope.searchUri = config
        $scope.resources = data.entry || []

initTags = ($scope)->
  $scope.tags = []

  schemes = {
   Security: "http://hl7.org/fhir/tag/security",
   Profile: "http://hl7.org/fhir/tag/profile",
   Tag: "http://hl7.org/fhir/tag/tag"
  }

  $scope.removeTag = (x)->
    tags = $scope.tags
    tags.splice(tags.indexOf(x),1)

  $scope.clearTags = ()->
    $scope.tags = []

  mkAdder = (schem)->
    ()-> $scope.tags.push({scheme: schem})

  $scope["add#{k}"] = mkAdder(s) for k,s of schemes

app.controller 'ResourcesNewCtrl', (menu, $fhir, $scope, $routeParams, $location) ->
  menu.build($routeParams, 'conformance', 'index', 'new*')

  $scope.resource = {}
  initTags($scope)

  rt = $routeParams.resourceType

  $scope.save = ->
    tags = $scope.tags.filter((i)-> i.term)
    $fhir.create entry: {content: angular.fromJson($scope.resource.content), category: tags}, success: ()->
      $location.path("/resources/#{rt}")

  $scope.validate = ()->
    res = $scope.resource.content
    tags = $scope.tags.filter((i)-> i.term)
    $fhir.validate entry: {content: angular.fromJson(res), category: tags}, success: ()->
      #alert('Valid')

pretifyJson = (str)-> angular.toJson(angular.fromJson(str), true)

app.controller 'ResourceCtrl', (menu, $fhir, $scope, $routeParams, $location) ->
  menu.build($routeParams,'conformance', 'index', 'show*', 'history', 'tags')

  rt = $routeParams.resourceType
  id = $routeParams.id
  initTags($scope)

  loadResource = ()->
    $fhir.read id: (rt + '/' + id), success: (data)->
      $scope.tags = data.category
      $scope.resource = { id: id, content: pretifyJson(data.content) }
      $scope.resourceContentLocation = data.id
      throw "content location required" unless $scope.resourceContentLocation

  loadResource()

  $scope.save = ->
    cl = $scope.resourceContentLocation
    res = $scope.resource.content
    tags = $scope.tags.filter((i)-> i.term)
    $fhir.update entry: {id: cl, content: angular.fromJson(res), category: tags}, success: (data)->
      $scope.resourceContentLocation = data.id
      throw "content location required" unless $scope.resourceContentLocation

  $scope.destroy = ->
    if window.confirm("Destroy #{$scope.resource.id}?")
      $fhir.delete entry: {id: $scope.resourceContentLocation}, success: ()-> $location.path("/resources/#{rt}")

  $scope.removeAllTags = ()->
    $fhir.removeTags type: rt, id: id, success: ()->
      $scope.tags = []

  $scope.affixResourceTags = ()->
    $fhir.affixTags type: rt, id: id, tags: $scope.tags, succes: (tagList)->
      console.log(tagList)
      $scope.tags = tagList.category

  $scope.validate = ()->
    cl = $scope.resourceContentLocation
    res = $scope.resource.content
    tags = $scope.tags.filter((i)-> i.term)
    console.log($fhir)
    $fhir.validate entry: {content: angular.fromJson(res), category: tags}, success: ()->
      #alert('Valid')

app.controller 'ResourceHistoryCtrl', (menu, $scope, $routeParams, $fhir) ->
  menu.build($routeParams, 'conformance', 'index', 'show', 'history*')

  $fhir.history
    type: $routeParams.resourceType
    id: $routeParams.id
    success: (data)->
      $scope.entries = data.entry
      $scope.history = data
      delete $scope.history.entry

app.controller 'ResourcesHistoryCtrl', (menu, $scope, $routeParams, $fhir) ->
  menu.build($routeParams, 'conformance', 'index', 'history_type*')

  $fhir.history
    type: $routeParams.resourceType
    success: (data)->
      $scope.entries = data.entry
      $scope.history = data
      delete $scope.history.entry

app.controller 'HistoryCtrl', (menu, $scope, $routeParams, $fhir) ->
  menu.build($routeParams, 'conformance', 'index_all', 'history_all*')

  $fhir.history
    success: (data)->
      $scope.entries = data.entry
      $scope.history = data
      delete $scope.history.entry

app.controller 'TagsCtrl', (menu, $scope, $routeParams, $fhir) ->
  menu.build($routeParams, 'conformance', 'index_all', 'tags_all*')

  $fhir.tags success: (data) ->
    $scope.tags = data

app.controller 'ResourcesTagsCtrl', (menu, $appFhir, $scope, $routeParams) ->
  menu.build($routeParams, 'conformance', 'index', 'tags_type*')

  $appFhir.tags_type $routeParams.resourceType, (data)->
    $scope.tags = data

app.controller 'ResourceTagsCtrl', (menu, $appFhir, $scope, $routeParams) ->
  menu.build($routeParams, 'conformance', 'index', 'show', 'tags*')

  $appFhir.tags $routeParams.resourceType, $routeParams.id, (data)->
    $scope.tags = data

app.controller 'TransactionCtrl', (menu, $appFhir, $scope, $routeParams, $location) ->
  menu.build($routeParams, 'conformance', 'index_all', 'transaction*')

  $scope.bundle = {}

  $scope.save = ->
    $appFhir.transaction $scope.bundle.content, ()->
      $location.path("/resources/Any")

app.controller 'DocumentCtrl', (menu, $appFhir, $scope, $routeParams, $location) ->
  menu.build($routeParams, 'conformance', 'index_all', 'document*')

  $scope.bundle = {}

  $scope.save = ->
    $appFhir.document $scope.bundle.content, ()->
      $location.path("/resources/Any")
