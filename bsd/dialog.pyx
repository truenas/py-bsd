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
            super(DialogEscape, self).__init__(defs.DLG_EXIT_ESC, "Escape out of dialog")
      def __str__(self):
            return "DialogEscape<>"
      
class FormLabel(object):
      """
      A wrapper object for form labels (and base class for input).
      This provides the name and x/y coordinates.
      """
      def __init__(self, label, width=None, position=None):
            self.label = label
            self.width = width if width else len(label) + 1
            self.position = position

      def __str__(self):
            return "<FormLabel(label={}, width={}, position={})>".format(
                  self.label, self.width, self.position)
      def __repr__(self):
            return "FormLabel({}, width={}, position={})".format(
                  self.label, self.width, self.position)
      
      """
      The label is presented as the name of the field.
      It can be empty.
      """
      @property
      def label(self):
            return self._label
      @label.setter
      def label(self, l):
            self._label = l
      """
      Label width is how wide on screen to use for the label.
      If set to None, then the length of the label string will
      be used.  Default for the constructor is to use the width
      of the label plus one space.
      """
      @property
      def width(self):
            return self._width
      @width.setter
      def width(self, w):
            self._width = w

      """
      The label position is where to place the label,
      relative to the form.  Values are <x, y>; None
      means to use a default, while <0, 0> means to use
      those coordinates.
      """
      @property
      def position(self):
            return self._coord
      @position.setter
      def position(self, c):
            self._coord = c

      
class FormInput(FormLabel):
      """
      A wrapper object for form input fields, which are a superset
      of label fields.  (They have maximum input widths in addition
      do display width.  Also, instead of "label" the text field is
      called "value.")
      """
      def __init__(self, value="",
                   width=None,
                   position=None,
                   maximum_input=None,
                   readonly=False):
            super(FormInput, self).__init__(value, width=width, position=position)
            self.maximum_input = maximum_input
            self.readonly = readonly

      def __str__(self):
            return "<FormInput(value={}, width={}, position={}, maximum_input={}, readonly={}>".format(
                  self.value, self.width, self.position, self.maximum_input, self.readonly)
      
      def __repr__(self):
            return "FormInput({}, width={}, position={}, maximum_input={}, readonly={})".format(
                  self.value, self.width, self.position, self.maximum_input, self.readonly)
      
      
      """
      The value of the field.  Before being processed, it
      shows up as the default value.  After being processed,
      it'll be at least ''.
      """
      @property
      def value(self):
            return self._label
      @value.setter
      def value(self, v):
            self._label = v

      """
      Maximum input size.  If set to None or 0, the form
      will use value_width.  Setting to larger allows for
      an input value wider than the display width.
      """
      @property
      def maximum_input(self):
            return self._max_input
      @maximum_input.setter
      def maximum_input(self, m):
            self._max_input = m
            
cdef UnpackFormItem(defs.DIALOG_FORMITEM *item):
      if False:
            with open("/tmp/form.log", "a") as f:
                  f.write("DIALOG_FORMITEM on input=<type={}, name={}, name_len={}, name_x={}, name_y={}, name_free={}, text={}, text_len={}, text_x={}, text_y={}, text_flen={}, text_ilen={}, text_free={}, help={}, help_free={}>\n".format(
                        item.type,
                        item.name or "(null)",
                        item.name_len,
                        item.name_x,
                        item.name_y,
                        item.name_free,
                        item.text or "(null)",
                        item.text_len,
                        item.text_x,
                        item.text_y,
                        item.text_flen,
                        item.text_ilen,
                        item.text_free,
                        item.help or "(null)",
                        item.help_free))

      pos_x = item.name_x
      pos_y = item.name_y
      if pos_x == 0 and pos_y == 0:
            pos = None
      else:
            pos = (pos_x, pos_y)
      label = FormLabel(item.name.decode('utf-8'),
                        width=item.name_len,
                        position=pos)
      pos_x = item.text_x
      pos_y = item.text_y
      if pos_x == 0 and pos_y == 0:
            pos = None
      else:
            pos = (pos_x, pos_y)
            
      value = FormInput(item.text.decode('utf-8'),
                        width=item.text_flen,
                        position=pos,
                        maximum_input=item.text_ilen)

      if False:
            with open("/tmp/form.log", "a") as f:
                  f.write("\tinput = {}\n".format(input))
                  f.write("\tvalue = {}\n".format(value))

      return FormItem(label, value=value,
                      help=item.help.decode('utf-8') if item.help else None,
                      hidden=bool(item.type & DialogType.HIDDEN),
                      readonly=bool(item.type & DialogType.READONLY))

cdef PackFormItem(item):
      cdef defs.DIALOG_FORMITEM *c_item
      print("PackFormItem({})".format(item))
      c_item = <defs.DIALOG_FORMITEM*>calloc(1, sizeof(defs.DIALOG_FORMITEM))
      c_item.name = strdup(item.label.label.encode('utf-8'))
      c_item.name_len = item.label.width or strlen(c_item.name)
      c_item.name_free = True
      if item.label.position:
            (c_item.name_x, c_item.name_y) = item.label.position
            
      c_item.text = strdup(item.value.value.encode('utf-8'))
      c_item.text_free = True
      if item.value.width:
            c_item.text_len = item.value.width
            c_item.text_flen = item.value.width
      elif item.value.readonly:
            c_item.text_len = 0
      else:
            c_item.text_len = strlen(c_item.text)

      if item.value.maximum_input:
            c_item.text_ilen = item.value.maximum_input
            
      if item.help:
            c_item.help = strdup(item.help.encode('utf-8'))
            c_item.help_free = True

      if False:
            with open("/tmp/form.log", "a") as f:
                  f.write("DIALOG_FORMITEM=<type={}, name={}, name_len={}, name_x={}, name_y={}, name_free={}, text={}, text_len={}, text_x={}, text_y={}, text_flen={}, text_ilen={}, text_free={}, help={}, help_free={}>\n".format(
                        c_item.type,
                        c_item.name,
                        c_item.name_len,
                        c_item.name_x,
                        c_item.name_y,
                        c_item.name_free,
                        c_item.text,
                        c_item.text_len,
                        c_item.text_x,
                        c_item.text_y,
                        c_item.text_flen,
                        c_item.text_ilen,
                        c_item.text_free,
                        c_item.help or "(null)",
                        c_item.help_free))
      
      retval = <bytes>(<char*>c_item)[:sizeof(defs.DIALOG_FORMITEM)]
      free(<void*>c_item)
      if False:
            c_item = <defs.DIALOG_FORMITEM*><char*>retval
            with open("/tmp/form.log", "a") as f:
                  f.write("\t<type={}, name={}, name_len={}, name_x={}, name_y={}, name_free={}, text={}, text_len={}, text_x={}, text_y={}, text_flen={}, text_ilen={}, text_free={}, help={}, help_free={}>\n".format(
                        c_item.type,
                        c_item.name or "(null?!?!)",
                        c_item.name_len,
                        c_item.name_x,
                        c_item.name_y,
                        c_item.name_free,
                        c_item.text or "(NULL?!?!?)",
                        c_item.text_len,
                        c_item.text_x,
                        c_item.text_y,
                        c_item.text_flen,
                        c_item.text_ilen,
                        c_item.text_free,
                        c_item.help or "(null)",
                        c_item.help_free))
      return retval

cdef class FormItem(object):
      """
      Item for a form (this includes password forms).
      A form item consists of a label and input field (see the
      appropriate classes above), as well as some optional
      flag fields.

      If the coordinates for the label and input fields are not
      specified (the object returns None), then the code will
      attempt to figure out a good location for them.  If they
      are specified, then those values will be used.  You should
      not mix, as the code isn't that smart:  the items are put
      at a progressively higher location, and the X location for
      input fields is based on the largest width of the label.
      """
      cdef:
            _label
            _value
            _help
            _hidden
            _readonly
            
      def __init__(self, label, value=None, help=None, hidden=False, readonly=False):
            self.label = label
            self.value = value
            self.help = help
            self.hidden = hidden
            self.readonly = readonly
            
      def __str__(self):
            return "<FormItem<label={}, value={}, help={}, hidden={}, readonly={}>".format(
                  self.label, self.value, self.help, self.hidden, self.readonly)
      def __repr__(self):
            return "FormItem({}, value={}, hidden={}, readonly={})".format(
                  self.label, self.value, self.help, self.hidden, self.readonly)

      property label:
          def __get__(self):
                return self._label
          def __set__(self, n):
                self._label = n
                
      property value:
          def __get__(self):
                return self._value
          def __set__(self, v):
                self._value = v
                
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
                
      def Pack(self):
            return PackFormItem(self)

      cdef Pack1(self, defs.DIALOG_FORMITEM *dst):
            memset(dst, 0, sizeof(defs.DIALOG_FORMITEM))
            print("self.label = {}".format(self.label))
            dst.name = strdup(self.label.label.encode('utf-8'))
            dst.name_len = strlen(dst.name)
            dst.name_free = True
            name_coord = self.label.position
            if name_coord is None:
                  # The caller has to clean this up
                  dst.name_x = 0
                  dst.name_y = 0
            else:
                  (dst.name_x, dst.name_y) = name_coord
            dst.text = strdup(self.value.value.encode('utf-8')) if self.value else strdup("")
            dst.text_len = strlen(dst.text) if dst.text else 30
            dst.text_free = True
            text_coord = self.value.position
            if text_coord is None:
                  # The caller has to clean this up
                  dst.text_x = 0
                  dst.text_y = 0
            else:
                  (dst.text_x, dst.text_y) = text_coord
                  
            dst.help = strdup(self.help.encode('utf-8')) if self.help else <char*>NULL
            if dst.help:
                  dst.help_free = True
            if self.hidden:
                  dst.type |= DialogType.HIDDEN
            if self.readonly:
                  dst.type |= DialogType.READONLY
            else:
                  if self.value.width is None:
                        dst.text_flen = len(self.value.value) + 10
                  if not self.value.maximum_input:
                        dst.text_ilen = 0
                  else:
                        dst.text_ilen = self.value.maximum_input

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
            cdef defs.DIALOG_FORMITEM *packed_item
            cdef int choice
            cdef defs.DIALOG_FORMITEM ci
            cdef FormItem fiLoopValue
            
            form_items = <defs.DIALOG_FORMITEM*>calloc(len(items) + 1, sizeof(defs.DIALOG_FORMITEM))

            self.savestate()
                  
            base_y = 1
            # We're going to cycle through the items to find the maximum label length
            max_label = 0
            for fiLoopValue in items:
                  if len(fiLoopValue.label.label) > max_label:
                        max_label = len(fiLoopValue.label.label)
                        
            for indx, fiLoopValue in enumerate(items):
                  temp_value = fiLoopValue.Pack()
                  packed_item = <defs.DIALOG_FORMITEM*><char*>temp_value
                  if False:
                        print("fiLoopValue[%d] = %s" % (indx, str(fiLoopValue)))
                        print("\tpacked_item.name: {}, len={}, free={}, pos=({}, {})".format(
                              packed_item.name,
                              packed_item.name_len,
                              packed_item.name_free,
                              packed_item.name_x,
                              packed_item.name_y))
                  memcpy(<void*>&form_items[indx], <void*>packed_item, sizeof(defs.DIALOG_FORMITEM))
                  incr = 0
                  if form_items[indx].name_y == 0:
                        form_items[indx].name_y = base_y
                        incr = 1
                  if form_items[indx].text_y == 0:
                        form_items[indx].text_y = base_y
                        incr = 1
                  if form_items[indx].text_x == 0:
                        form_items[indx].text_x = max_label + 3
                  base_y  += incr

            if width is None:
                  width = len(title) + 10

            if form_height is None:
                  form_height = len(items)
            if form_height > height:
                  list_height = max(height - 5, 1)

            if False:
                  for indx in range(0, len(items)):
                        print("form_item[%d]: name = { `%s`, len:%d, pos:(%d, %d), free:%d }, text = { `%s`, len:%d, pos:(%d, %d), free:%d}" % (indx,
                                                                                                                                                form_items[indx].name or "(null)", form_items[indx].name_len, form_items[indx].name_x, form_items[indx].name_y, form_items[indx].name_free,
                                                                                                                                                form_items[indx].text or "(null)", form_items[indx].text_len, form_items[indx].text_x, form_items[indx].text_y, form_items[indx].text_free))

            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            if password:
                  defs.dialog_vars.insecure = 1

            result = defs.dlg_form(title.encode('utf-8'),
                                   prompt.encode('utf-8'),
                                   height, width, form_height,
                                   len(items),
                                   form_items, &choice)
            defs.end_dialog()
            
            self.restorestate()
            for indx in range(len(items)):
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

