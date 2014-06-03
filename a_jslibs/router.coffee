# Simply a backbone router with a single added function
# goto() which can be called with either
#   a) a page name
#   b) a function that returns a page name
#
# A ReactiveRouter has a reactive variable .current_page.get() that returns the result 
# whatever is set via goto().
class ReactiveVar
  constructor: (initval) ->
    console.log "creating deppp"
    @dep = new Deps.Dependency
    @val = initval
  
  get: ->
    @dep.depend()
    return @val
    
  set: (val)->
    @val = val
    @dep.changed()
    

@ReactiveRouter = Backbone.Router.extend(
  initialize: ->
    @current_page = new ReactiveVar "loading"
    Backbone.Router::initialize.call this

  
  # simply wrap a page generating function in a context so we can set current_page
  # every time that it changes, but we can ensure that we only call it once (in case of side-effects) 
  # TODO -- either generalize this pattern or get rid of it
  goto: (page_f) ->

    self = this
#    
#    # so there's no need to specify constant functions
#    if typeof (page_f) isnt "function"
#      copy = page_f
#      page_f = ->
#        copy
#    
#    # clean up the old context
#    if self.context
#      self.context.finished = true
#      self.context.invalidate()
#    self.context = new Meteor.deps.Context()
#    self.context.on_invalidate (context) ->
#      ReactiveRouter::goto.call self, page_f  unless context.finished
#
#    self.context.run ->
    self.current_page.set page_f

)

# A FilteredRouter is a ReactiveRouter with an API for filtering.
#
# call Router.filter(fn, options)
#
# to wrap all goto() calls in fn, assuming options fit, where options are:
#   - only: array of names that fn should be called for
#   - except: array of names that fn should not be called for.
@FilteredRouter = ReactiveRouter.extend(
  initialize: ->
    @_filters = []
    ReactiveRouter::initialize.call this

  
  # normal goto, but runs the output of page_f through the filters
  goto: (page_f) ->
    self = this
    
    # so there's no need to specify constant functions
    if typeof (page_f) isnt "function"
      copy = page_f
      page_f = ->
        copy
    ReactiveRouter::goto.call this, ->
      self.apply_filters page_f()


  
  # set up a filter
  filter: (fn, options) ->
    options = {}  if options is `undefined`
    options.fn = fn
    @_filters.push options

  
  # run all filters over page
  apply_filters: (page) ->
    self = this
    _.reduce self._filters, ((page, filter) ->
      self.apply_filter page, filter
    ), page

  
  # run a single filter (check only and except)
  apply_filter: (page, filter) ->
    apply = true
    if filter.only
      apply = _.include(filter.only, page)
    else apply = not _.include(filter.except, page)  if filter.except
    if apply
      filter.fn page
    else
      page
)