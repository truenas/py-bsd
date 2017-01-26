import os, sys
import types
import enum

from libc.stdlib cimport malloc, free, calloc
from libc.string cimport memset, strdup, strlen

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
                      value=item.text.decode('utf-8') if item.text else None,
                      help=item.help.decode('utf-8') if item.help else None,
                      hidden=bool(item.type & DialogType.HIDDEN),
                      readonly=bool(item.type & DialogType.READONLY))

cdef class FormItem(object):
      cdef:
            _name
            _value
            _help
            _hidden
            _readonly
            _label_x
            _label_y
            _text_x
            _text_y
            _text_maximum
            
      def __init__(self, name, value=None, help=None, hidden=False, readonly=False):
            self.name = name
            self.value = value
            self.help = help
            self.hidden = hidden
            self.readonly = readonly

      def __str__(self):
            return "<FormItem<name={}, value={}, help={}, hidden={}, readonly={}>".format(
                  self.name, self.value, self.help, self.hidden, self.readonly)
      def __repr__(self):
            return "FormItem({}, value={}, help={}, hidden={}, readonly={})".format(
                  self.name, self.value, self.help, self.hidden, self.readonly)
      @property
      def name(self):
            return self._name
      @name.setter
      def name(self, n):
            self._name = n

      @property
      def value(self):
            return self._value
      @value.setter
      def value(self, v):
            self._value = v

      @property
      def help(self):
            return self._help
      @help.setter
      def help(self, h):
            self._help = h

      @property
      def hidden(self):
            return self._hidden

      @hidden.setter
      def hidden(self, v):
            self._hidden = bool(v)

      @property
      def readonly(self):
            return self._readonly

      @readonly.setter
      def readonly(self, v):
            self._readonly = bool(v)

      cdef Pack(self, defs.DIALOG_FORMITEM *dst):
            memset(dst, 0, sizeof(defs.DIALOG_FORMITEM))
            dst.name = strdup(self.name.encode('utf-8'))
            dst.name_len = strlen(dst.name)
            dst.text = strdup(self.value.encode('utf-8')) if self.value else strdup("")
            dst.text_len = strlen(dst.text) if dst.text else 30
            dst.help = strdup(self.help.encode('utf-8')) if self.help else <char*>NULL
            if self.hidden:
                  dst.type |= DialogType.HIDDEN
            if self.readonly:
                  dst.type |= DialogType.READONLY
            else:
                  # We need to change some things
                  dst.text_flen = 30
                  dst.text_ilen = 30

class Dialog(object):
      """
      Python interface to libdialog.
      Note that libdialog is AWFUL:  it relies on multiple
      global-state variables.  We try to work around that
      as best we can.
      """
      def __init__(self, input=sys.stdin, output=sys.stdout):
            global defs
            if input is sys.stdin:
                  defs.dialog_state.input = defs.stdin
            if output is sys.stdout:
                  defs.dialog_state.output = defs.stdout
                  

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
               form_height=None, items=None):
            """
            Present a form.  items is an array of FormItem objects.
            Modifies the FormItem objects in place.
            Raises an exception when cancelled or if an error occurs.
            """
            if not items:
                  raise ValueError("Form items must contain values")

            cdef defs.DIALOG_FORMITEM *form_items
            cdef int choice
            cdef defs.DIALOG_FORMITEM ci
            cdef FormItem fiLoopValue
            
            form_items = <defs.DIALOG_FORMITEM*>calloc(len(items) + 1, sizeof(defs.DIALOG_FORMITEM))

            base_y = 1
            for indx, fiLoopValue in enumerate(items):
                  fiLoopValue.Pack(&form_items[indx])
                  form_items[indx].name_y = base_y
                  form_items[indx].text_y = base_y
                  form_items[indx].text_x = strlen(form_items[indx].name) + 3
                  base_y  += 1

            if width is None:
                  width = len(title) + 10

            if form_height is None:
                  form_height = len(items)
            if form_height > height:
                  list_height = max(height - 5, 1)

            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            result = defs.dlg_form(title.encode('utf-8'),
                                   prompt.encode('utf-8'),
                                   height, width, form_height,
                                   len(items),
                                   form_items, &choice)
            
            for indx in range(len(items)):
                  fiLoopItem = form_items[indx]
                  items[indx] = UnpackFormItem(&form_items[indx])
                                                 
            i = 0
            while i < indx:
                  free(form_items[i].name)
                  free(form_items[i].text)
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

