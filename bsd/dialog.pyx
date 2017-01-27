import os, sys
import types
import enum

from libc.stdlib cimport malloc, free, calloc
from libc.string cimport memset, strdup, strlen, memcpy

cimport cython
cimport defs

class DialogType(enum.IntEnum):
      READONLY = 2
      HIDDEN = 1
      
class DialogError(Exception):
      def __init__(self, code=0, message=None):
            self.code = code
            self.message = message
      def __str__(self):
            return "DialogError<code={}, message={}>".format(self.code, self.message)

class DialogEscape(DialogError):
      def __init__(self):
            super(DialogError, self).__init__(defs.DLG_EXIT_ESC, "Escape out of dialog")
      def __str__(self):
            return "DialogEscape<>"
      
cdef UnpackFormItem(defs.DIALOG_FORMITEM *item):
      return FormItem(item.name.decode('utf-8'),
                      text=item.text.decode('utf-8') if item.text else None,
                      help=item.help.decode('utf-8') if item.help else None,
                      hidden=bool(item.type & DialogType.HIDDEN),
                      readonly=bool(item.type & DialogType.READONLY))

cdef class FormItem(object):
      """
      Item for a form (this includes password forms).
      Most of the members are fairly self-explanatory, but a note
      needs to be made about positioning:  a FormItem can specify
      its x and y coordinates for both the label and the field, or
      it can leave them at none, in which case the form code will
      attempt to figure something out.  (Each subsequent one will
      go at a higher Y value, the X value of the form field will be
      based on all the fields' labels, etc.)
      N.B. Most of that is not implemented yet.
      """
      cdef:
            _label
            _text
            _help
            _hidden
            _readonly
            _label_pos
            _text_pos
            _text_maximum
            
      def __init__(self, label, text=None, help=None, hidden=False, readonly=False):
            self.label = label
            self.text = text
            self.help = help
            self.hidden = hidden
            self.readonly = readonly
            self.label_pos = None
            self.text_pos = None
            
      def __str__(self):
            return "<FormItem<label={}, text={}, help={}, hidden={}, readonly={}>".format(
                  self.label, self.text, self.help, self.hidden, self.readonly)
      def __repr__(self):
            return "FormItem({}, text={}, hidden={}, readonly={})".format(
                  self.label, self.text, self.help, self.hidden, self.readonly)

      property label_pos:
          def __get__(self):
                return self._label_pos
          def __set__(self, p):
                self._label_pos = p

      property text_pos:
          def __get__(self):
                return self._text_pos
          def __set__(self, p):
                self._text_pos = p

      property label:
          def __get__(self):
                return self._label
          def __set__(self, n):
                self._label = n
                
      property text:
          def __get__(self):
                return self._text
          def __set__(self, v):
                self._text = v
                
      property help:
          def __get__(self):
                return self._help
          def __set__(self, v):
                self._help = v
                
      property hidden:
          def __get__(self):
                return self._hidden
          def __set__(self, b):
                self._hidden = bool(b)

      property readonly:
          def __get__(self):
                return self._readonly
          def __set__(self, b):
                self._readonly = bool(b)
                
      cdef Pack(self, defs.DIALOG_FORMITEM *dst):
            memset(dst, 0, sizeof(defs.DIALOG_FORMITEM))
            dst.name = strdup(self.label.encode('utf-8'))
            dst.name_len = strlen(dst.name)
            dst.name_free = True
            dst.text = strdup(self.text.encode('utf-8')) if self.text else strdup("")
            dst.text_len = strlen(dst.text) if dst.text else 30
            dst.text_free = True
            dst.help = strdup(self.help.encode('utf-8')) if self.help else <char*>NULL
            if dst.help:
                  dst.help_free = True
            if self.hidden:
                  dst.type |= DialogType.HIDDEN
            if self.readonly:
                  dst.type |= DialogType.READONLY
            else:
                  # We need to change some things
                  dst.text_flen = 30
                  dst.text_ilen = 30

"""
cdef _save_dialog_state():
      cdef void *vars_buffer
      cdef void *state_buffer

      vars_buffer = calloc(1, sizeof(defs.DIALOG_VARS))
      memcpy(vars_buffer, <void*>&defs.dialog_vars, sizeof(defs.DIALOG_VARS))
      state_buffer = calloc(1, sizeof(defs.DIALOG_STATE))
      memcpy(state_buffer, <void*>&defs.dialog_state, sizeof(defs.DIALOG_STATE))
      
      return (<bytes>vars_buffer, <bytes>state_buffer)
"""
cdef _save_dialog_state():
      vars_buffer = <bytes>(<char*>&defs.dialog_vars)[:sizeof(defs.DIALOG_VARS)]
      state_buffer = <bytes>(<char*>&defs.dialog_state)[:sizeof(defs.DIALOG_STATE)]
      return (vars_buffer, state_buffer)

cdef _restore_dialog_state(state):
      memcpy(<void*>&defs.dialog_state, <void*>(state[0]), sizeof(defs.DIALOG_STATE))
      memcpy(<void*>&defs.dialog_vars, <void*>(state[1]), sizeof(defs.DIALOG_VARS))

class Dialog(object):
      """
      Python interface to libdialog.
      Note that libdialog is AWFUL:  it relies on multiple
      global-state variables.  We try to work around that
      as best we can.  Also, we only allow one window at
      a time.
      """
      def __init__(self, input=sys.stdin, output=sys.stdout):
            global defs
            if input is sys.stdin:
                  defs.dialog_state.input = defs.stdin
            if output is sys.stdout:
                  defs.dialog_state.output = defs.stdout
            self.state_saved = False

      def savestate(self):
            if self.state_saved:
                  return
            self.saved_context = _save_dialog_state()
            self.state_saved = True

      def restorestate(self):
            if self.state_saved:
                  _restore_dialog_state(self.saved_context)
                  self.state_saved = False
            return
      
      def yesno(self, title, prompt, height=10, width=None,
                default=True, yes_label=None, no_label=None):
            """
            Dialog window with two options (default "Yes" and "No").
            By default, the Yes button is selected.
            Paranters:
            - title: str (required)
            - prompt: str (required)
            - height: int (defaults to 10, which is dumb)
            - width: int or None (in which case it'll be the length of the title + 10)
            - default: bool (which value is selected by default:  True=yes, False=no)
            - yes_label: str
            - no_label: str
            Raises:
            - DialogEscape if escape was hit
            - DialogError for any other error from libdialog
            Returns:
            - boolean (True for yes-value, False for no-value)
            """
            if not width:
                  width = len(title) + 10
            
            stupid_yes_temp_label = yes_label.encode("utf-8") if yes_label else None
            defs.dialog_vars.yes_label = stupid_yes_temp_label or <char*>NULL

            stupid_no_temp_label = no_label.encode("utf-8") if no_label else None
            defs.dialog_vars.no_label = stupid_no_temp_label or <char*>NULL
                  
            if default:
                  defs.dialog_vars.defaultno = False
            else:
                  defs.dialog_vars.defaultno = True
                  defs.dialog_vars.default_button = defs.DLG_EXIT_CANCEL
                  
            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            rv = defs.dialog_yesno(title.encode("utf-8"), prompt.encode("utf-8"), height, width)
            defs.end_dialog()

            # Convert dialog return value to boolean
            if rv == defs.DLG_EXIT_OK:
                  return True
            elif rv == defs.DLG_EXIT_CANCEL:
                  return False
            elif rv == defs.DLG_EXIT_ESC:
                  raise DialogEscape
            else:
                  raise DialogError(code=rv, message="Unknown return value")

      def msgbox(self, title, prompt, height=10, width=None, label=None):
            """
            Display a message, with an OK button.  (Use label if set.)
            """
            cdef char *old_label

            old_label = defs.dialog_vars.ok_label
            stupid_label_temp = label.encode("utf-8") if label else None
            defs.dialog_vars.ok_label = stupid_label_temp or <char*>NULL
            
            if width is None:
                  width = len(title) + 10

            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            result = defs.dialog_msgbox(title.encode('utf-8'),
                                        prompt.encode('utf-8'),
                                        height, width, 1)
            defs.end_dialog()
            defs.dialog_vars.ok_label = old_label
            
            if result in (defs.DLG_EXIT_OK, defs.DLG_EXIT_CANCEL):
                  pass
            elif result == defs.DLG_EXIT_ESC:
                  raise DialogEscape
            else:
                  raise DialogError(code=result, message="Unknown return value")

                                        
      def form(self, title, prompt, height=10, width=None,
               form_height=None, items=None, password=False):
            """
            Present a form.  items is an array of FormItem objects.
            Modifies the FormItem objects in place.
            Raises an exception when cancelled or if an error occurs.
            Right now, password=True implies insecure.
            """
            if not items:
                  raise ValueError("Form items must contain values")

            cdef defs.DIALOG_FORMITEM *form_items
            cdef int choice
            cdef defs.DIALOG_FORMITEM ci
            cdef FormItem fiLoopValue
            
            form_items = <defs.DIALOG_FORMITEM*>calloc(len(items) + 1, sizeof(defs.DIALOG_FORMITEM))

            self.savestate()
                  
            base_y = 1
            # We're going to cycle through the items to find the maximum label length
            max_label = 0
            for fiLoopValue in items:
                  if len(fiLoopValue.label) > max_label:
                        max_label = len(fiLoopValue.label)
                        
            for indx, fiLoopValue in enumerate(items):
                  fiLoopValue.Pack(&form_items[indx])
                  form_items[indx].name_y = base_y
                  form_items[indx].text_y = base_y
                  form_items[indx].text_x = max_label + 3
                  base_y  += 1

            if width is None:
                  width = len(title) + 10

            if form_height is None:
                  form_height = len(items)
            if form_height > height:
                  list_height = max(height - 5, 1)

            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            if password:
                  defs.dialog_vars.insecure = 1
            result = defs.dlg_form(title.encode('utf-8'),
                                   prompt.encode('utf-8'),
                                   height, width, form_height,
                                   len(items),
                                   form_items, &choice)
            defs.end_dialog()
            
#            self.restorestate()
            for indx in range(len(items)):
                  fiLoopItem = form_items[indx]
                  items[indx] = UnpackFormItem(&form_items[indx])
                                                 
            i = 0
            while i < indx:
                  if form_items[i].name_free:
                        free(form_items[i].name)
                  if form_items[i].text_free:
                        free(form_items[i].text)
                  if form_items[i].help and form_items[i].help_free:
                        free(form_items[i].help)
                  i += 1
            free(form_items)
            return result
      
      def checklist(self, title, prompt,
                    height=10, width=None,
                    list_height=None,
                    items=None,
                    radio=False):
            """
            Create a checklist.  list_height must be less than height; it'll attempt
            to adjust automatically if list_height is None.
            items is a dictionary keyed by name, with { text, help, state } keys.
            (All are str except for state, which is boolean.)  help may be None
            If radio is true, then only one item may be selected at a time.
            Returns a dictionary with the state=True items, keyed by name.
            """
            
            if not items:
                  raise ValueError("Check list must have items")

            cdef defs.DIALOG_LISTITEM *list_items;
            cdef int current_choice = 0

            list_items = <defs.DIALOG_LISTITEM*>calloc(len(items) + 1, sizeof(defs.DIALOG_LISTITEM))

            indx = 0
            for name, values in items.items():
                  tmp_name_str = name.encode('utf-8')
                  if "text" in values:
                        tmp_text_str = values["text"].encode('utf-8')
                  else:
                        raise ValueError("Checklist items must have a text string")
                  if "help" in values:
                        tmp_help_str = values["help"].encode('utf-8')
                  else:
                        tmp_help_str = None
                  if "state" in values:
                        state = bool(values["state"])
                  else:
                        state = False
                  list_items[indx].name = strdup(tmp_name_str)
                  list_items[indx].text = strdup(tmp_text_str)
                  list_items[indx].help = strdup(tmp_help_str) if tmp_help_str else <char*>NULL
                  list_items[indx].state = state
                  indx += 1
                  
            i = 0
            while i < indx:
                  print("list_items[{}]: name = {}, text = {}, state = {}".format(i, list_items[i].name, list_items[i].text, bool(list_items[i].state)))
                  i += 1
                  
            if width is None:
                  width = len(title) + 10

            if list_height is None:
                  list_height = len(items)
            if list_height > height:
                  list_height = max(height - 5, 1)
                  
            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            result = defs.dlg_checklist(title.encode('utf-8'),
                                        prompt.encode('utf-8'),
                                        height, width, list_height,
                                        len(items),
                                        list_items, <char*>NULL,
                                        defs.FLAG_RADIO if radio else defs.FLAG_CHECK,
                                        &current_choice)
            defs.end_dialog()

            i = 0
            rv = {}
            while i < len(items):
                  if list_items[i].state:
                        tnam = list_items[i].name.decode("utf-8")
                        
                        rv[tnam] = {
                              "text" : list_items[i].text.decode('utf-8'),
                              "state" : bool(list_items[i].state)
                              }
                        if list_items[i].help:
                              rv[tnam]["help"] = list_items[i].help.decode('utf-8')
                              
                  free(list_items[i].name)
                  free(list_items[i].text)
                  free(list_items[i].help)
                  i += 1
            free(list_items)
                                                
            if result in (defs.DLG_EXIT_OK, defs.DLG_EXIT_CANCEL):
                  pass
            elif result == defs.DLG_EXIT_ESC:
                  raise DialogEscape
            else:
                  raise DialogError(code=result, message="Unknown return value")

            return rv

