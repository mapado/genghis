{_}         = require '../vendors'
CodeMirror  = require '../shims/codemirror'
View        = require './view.coffee'
GenghisJSON = require '../json.coffee'
AlertView   = require './alert.coffee'
Alert       = require '../models/alert.coffee'
defaults    = require '../defaults.coffee'
template    = require '../../templates/edit_document.mustache'

class EditDocument extends View
  template:     template
  errorLines:   []
  showControls: true

  ui:
    '$textarea': 'textarea'

  events:
    'click button.save':   'save'
    'click button.cancel': 'cancel'

  dataEvents:
    'attached this': 'refreshEditor'

  serialize: ->
    id:           @model?.id?.replace('~', '-') or 'new',
    showControls: @showControls

  afterRender: =>
    @$textarea.text(@model.JSONish())
    @editor = CodeMirror.fromTextArea(@$textarea[0], _.extend({}, defaults.codeMirror,
      autofocus: true
      extraKeys:
        'Ctrl-Enter': @save
        'Cmd-Enter':  @save
    ))
    @editor.setSize(null, @height) if @height

    # hax!
    if _.isEmpty(@model.attributes)
      @editor.setValue("{\n    \n}\n")
      @editor.setCursor(line: 1, ch: 4)

    @$textarea.resize(_.throttle(@editor.refresh, 100))
    @listenTo(@$textarea, 'focused blurred', (e) => @trigger(e))

  clearErrors: ->
    @getErrorBlock().empty()
    _.each @errorLines, (marker) =>
      @editor.removeLineClass marker, 'background', 'error-line'
    @errorLines = []

  getEditorValue: ->
    @clearErrors()
    try
      return GenghisJSON.parse(@editor.getValue())
    catch e
      _.each e.errors or [e], (error) =>
        message = error.message
        if error.lineNumber and not (/Line \d+/i.test(message))
          message = "Line #{error.lineNumber}: #{error.message}"
        alertView = new AlertView(model: new Alert(level: 'danger', msg: message, block: true))
        @getErrorBlock().append(alertView.render().el)
        if error.lineNumber
          @errorLines.push(@editor.addLineClass(error.lineNumber - 1, 'background', 'error-line'))
    false

  save: =>
    data = @getEditorValue()
    return if data is false

    @model.clear(silent: true)
    @model.save(data, wait: true)
      .done(@cancel)
      .fail((doc, xhr) =>
        try
          msg = JSON.parse(xhr.responseText).error
        @showServerError(msg or 'Error updating document.')
      )

  cancel: =>
    @detach()

  refreshEditor: =>
    @editor.refresh()
    @editor.focus()

  getErrorBlock: ->
    return @errorBlock if @errorBlock?
    @errorBlock = $('<div class="errors"></div>').insertBefore(@$el)

  showServerError: (message) =>
    alert     = new Alert(level: 'danger', msg: message, block: true)
    alertView = new AlertView(model: alert)
    @getErrorBlock().append alertView.render().el

module.exports = EditDocument
