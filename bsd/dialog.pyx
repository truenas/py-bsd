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

class ListItem(object):
      """
      A wrapper object for checklists / radio boxes.
      Each item has a label, descriptive text, optional help,
      and a state.
      """
      def __init__(self, label, text, help=None, state=False):
            self.label = label
            self.text = text
            self.help = help
            self.state = state
      @property
      def label(self):
            return self._label
      @label.setter
      def label(self, l):
            self._label = l
      @property
      def text(self):
            return self._text
      @text.setter
      def text(self, t):
            self._text = t
      @property
      def help(self):
            return self._help
      @help.setter
      def help(self, h):
            self._help = h
      @property
      def state(self):
            return self._state
      @state.setter
      def state(self, b):
            self._state = bool(b)
            
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
                   readonly=False,
                   hidden=False):
            super(FormInput, self).__init__(value, width=width, position=position)
            self.maximum_input = maximum_input
            self.readonly = readonly
            self.hidden = hidden
            
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
            
      """
      Hidden field or not.  Usually unused, even for password
      forms.
      """
      @property
      def hidden(self):
            return self._hidden
      @hidden.setter
      def hidden(self, b):
            self._hidden = bool(b)
            
cdef _clear_dialog_state():
      memset(<void*>&defs.dialog_state, 0, sizeof(defs.dialog_state))
      memset(<void*>&defs.dialog_vars, 0, sizeof(defs.dialog_vars))
      
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
                        maximum_input=item.text_ilen,
                        hidden=(item.type == 1))

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

      if item.value.hidden:
            c_item.type = 1
            
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
      print("save:  vars_buffer = {}, state_buffer = {}".format(vars_buffer, state_buffer))
      return (vars_buffer, state_buffer)

cdef _restore_dialog_state(state):
      print("restore:  vars_buffer = {}, state_buffer = {}".format(state[0], state[1]))
      memcpy(<void*>&defs.dialog_vars, <void*>state[0], sizeof(defs.DIALOG_VARS))
      memcpy(<void*>&defs.dialog_state, <void*>state[1], sizeof(defs.DIALOG_STATE))

class Dialog(object):
      """
      Python interface to libdialog.
      Note that libdialog is AWFUL:  it relies on multiple
      global-state variables.  We try to work around that
      as best we can.  Also, we only allow one window at
      a time.
      """
      def __init__(self, title, prompt, **kwargs):
            self.title = title
            self.prompt = prompt
            self.height = kwargs.pop("height", 10)
            self.width = kwargs.pop("width", len(self.title) + 10)
            self._result = None
            _clear_dialog_state()

            # I'm not sure these make any sense
            #defs.dialog_state.input = kwargs.pop("input", defs.stdin)
            #defs.dialog_state.output = kwargs.pop("output", defs.stdout)
            defs.dialog_state.input = defs.stdin
            defs.dialog_state.output = defs.stdout
            
            self.ok_label = kwargs.pop("ok_label", None)
            self.no_label = kwargs.pop("no_label", None)
            self.yes_label = kwargs.pop("yes_label", None)
            self.cancel_label = kwargs.pop("cancel_label", None)
            
      def run(self):
            return None
      
      @property
      def result(self):
            # This SHOULD be over-ridden by subclasses
            if self._result is None:
                  self._result = self.run()
            # Translate OK->True, CANCEL->False, ESC->DialogEscape, other to DialogError
            if self._result == defs.DLG_EXIT_OK:
                  self._result = True
            elif self._result == defs.DLG_EXIT_CANCEL:
                  self._result = False
            elif self._result == defs.DLG_EXIT_ESC:
                  raise DialogEscape
            else:
                  raise DialogError(code=self._result, message="Unknown dialog return value {}".format(self._result))
            return self._result
            
      @property
      def title(self):
            return self._title
      @title.setter
      def title(self, t):
            self._title = t

      @property
      def prompt(self):
            return self._prompt
      @prompt.setter
      def prompt(self, p):
            self._prompt = p
            
      @property
      def height(self):
            return self._height
      @height.setter
      def height(self, h):
            self._height = h

      @property
      def width(self):
            return self._width
      @width.setter
      def width(self, w):
            self._width = w
            
      """
      Labels:  OK, No, Yes, Cancel
      """
      @property
      def ok_label(self):
            tstr = defs.dialog_vars.ok_label
            if tstr:
                  return tstr.decode('utf-8')
            else:
                  return "OK"
      @ok_label.setter
      def ok_label(self, txt):
            if txt:
                  tmp_stupid_string = txt.encode('utf-8')
                  defs.dialog_vars.ok_label = strdup(tmp_stupid_string)
            else:
                  free(defs.dialog_vars.ok_label)
                  defs.dialog_vars.ok_label = <char*>NULL

      @property
      def no_label(self):
            tstr = defs.dialog_vars.no_label
            if tstr:
                  return tstr.decode('utf-8')
            else:
                  return "No"
      @no_label.setter
      def no_label(self, txt):
            if txt:
                  tmp_stupid_string = txt.encode('utf-8')
                  defs.dialog_vars.no_label = strdup(tmp_stupid_string)
            else:
                  free(defs.dialog_vars.no_label)
                  defs.dialog_vars.no_label = <char*>NULL

      @property
      def yes_label(self):
            tstr = defs.dialog_vars.yes_label
            if tstr:
                  return tstr.decode('utf-8')
            else:
                  return "Yes"
      @yes_label.setter
      def yes_label(self, txt):
            if txt:
                  tmp_stupid_string = txt.encode('utf-8')
                  defs.dialog_vars.yes_label = strdup(tmp_stupid_string)
            else:
                  free(defs.dialog_vars.yes_label)
                  defs.dialog_vars.yes_label = <char*>NULL

      @property
      def cancel_label(self):
            tstr = defs.dialog_vars.cancel_label
            if tstr:
                  return tstr.decode('utf-8')
            else:
                  return "Cancel"
      @cancel_label.setter
      def cancel_label(self, txt):
            if txt:
                  tmp_stupid_string = txt.encode('utf-8')
                  defs.dialog_vars.cancel_label = strdup(tmp_stupid_string)
            else:
                  free(defs.dialog_vars.cancel_label)
                  defs.dialog_vars.cancel_label = <char*>NULL
                  
      def clear(self):
            defs.dlg_clear()
            
class YesNo(Dialog):
      """
      Dialog window with two options (default "Yes" and "No").
      By default, the Yes button is selected.
      """
      def __init__(self, title, prompt, **kwargs):
            super(YesNo, self).__init__(title, prompt, **kwargs)
            self.default = kwargs.pop("default", False)

      def run(self):
            """
            Do all the work.
            """
            print("yes_label = {}, no_label = {}".format(
                  self.yes_label, self.no_label))

            if self.default:
                  defs.dialog_vars.defaultno = False
            else:
                  defs.dialog_vars.defaultno = True
                  defs.dialog_vars.default_button = defs.DLG_EXIT_CANCEL
                  
            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            rv = defs.dialog_yesno(self.title.encode("utf-8"),
                                   self.prompt.encode("utf-8"),
                                   self.height, self.width)
            defs.end_dialog()
            return rv

      @property
      def default(self):
            return self._default
      @default.setter
      def default(self, b):
            self._default = b

class MessageBox(Dialog):
      def __init__(self, title, prompt, **kwargs):
            """
            Display a message, with an OK button.  (Use the label if set.)
            """
            super(MessageBox, self).__init__(title, prompt, **kwargs)
            self.label = kwargs.pop("label", None)

      @property
      def label(self):
            return self._label
      @label.setter
      def label(self, l):
            self._label = l

      def run(self):
            if self.width is None:
                  self.width = len(self.title) + 10

            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            result = defs.dialog_msgbox(self.title.encode('utf-8'),
                                        self.prompt.encode('utf-8'),
                                        self.height, self.width, 1)
            defs.end_dialog()

            if result in (defs.DLG_EXIT_OK, defs.DLG_EXIT_CANCEL):
                  return defs.DLG_EXIT_OK
            return result

class Menu(Dialog):
      def __init__(self, title, prompt, **kwargs):
            super(Menu, self).__init__(title, prompt, **kwargs)
            # Note that these can be set later
            self.menu_height = kwargs.pop("menu_height", None)
            self.menu_items = kwargs.pop("menu_items", None)

      @property
      def menu_height(self):
            return self._menu_height
      @menu_height.setter
      def menu_height(self, m):
            self._menu_height = m

      @property
      def menu_items(self):
            return self._items
      @menu_items.setter
      def menu_items(self, i):
            self._items = i
            
      def run(self):
            if not self.menu_items:
                  raise ValueError("Menu must have items to display")
            cdef defs.DIALOG_LISTITEM *list_items
            cdef int current_item = 0

            list_items = <defs.DIALOG_LISTITEM*>calloc(len(self.menu_items) + 1, sizeof(defs.DIALOG_LISTITEM))
            if list_items == NULL:
                  raise MemoryError("Could not allocate {} items for menu".format(len(self.menu_items) + 1))

            for indx, item in enumerate(self.menu_items):
                  tmp_name_str = str(indx + 1).encode('utf-8')
                  tmp_text_str = item.label.encode('utf-8')
                  list_items[indx].name = strdup(tmp_name_str)
                  list_items[indx].text = strdup(tmp_text_str)

            if self.width is None:
                  self.width = len(self.title) + 10

            if self.menu_height is None:
                  self.menu_height = len(self.menu_items)
            if self.menu_height > self.height:
                  self.menu_height = max(self.height - 5, 1)

            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            result = defs.dlg_menu(self.title.encode('utf-8'),
                                   self.prompt.encode('utf-8'),
                                   self.height, self.width, self.menu_height,
                                   len(self.menu_items),
                                   list_items,
                                   &current_item,
                                   &defs.dlg_dummy_menutext)
            defs.end_dialog()

            # current_item has the selected choice.
            if result == defs.DLG_EXIT_OK:
                  rv = list_items[current_item].text.decode('utf-8')
            else:
                  rv = None
                  
            for i in range(len(self.menu_items)):
                  free(list_items[i].name)
                  free(list_items[i].text)
                  free(list_items[i].help)
            free(list_items)

            if result == defs.DLG_EXIT_OK:
                  self._result = rv
            elif result == defs.DLG_EXIT_CANCEL:
                  self._result = None
            elif result == defs.DLG_EXIT_ESC:
                  raise DialogEscape
            else:
                  raise DialogError(code=result, message="Unknown return value")

      @property
      def result(self):
            if self._result is None:
                  self.run()
            return self._result
      
class CheckList(Dialog):
      def __init__(self, title, prompt, **kwargs):
            super(CheckList, self).__init__(title, prompt, **kwargs)

            self.list_height = kwargs.pop("list_height", None)
            self.list_items = kwargs.pop("list_items", None)
            self._radio = False
            
      @property
      def list_height(self):
            return self._list_height
      @list_height.setter
      def list_height(self, h):
            self._list_height = h

      @property
      def list_items(self):
            return self._items
      @list_items.setter
      def list_items(self, l):
            self._items = l
            

      def run(self):
            if not self.list_items:
                  raise ValueError("A checklist needs item to check")

            cdef defs.DIALOG_LISTITEM *list_items;
            cdef int current_choice = 0

            list_items = <defs.DIALOG_LISTITEM*>calloc(len(self.list_items) + 1, sizeof(defs.DIALOG_LISTITEM))

            for indx, item in enumerate(self.list_items):
                  tmp_name_str = (item.label if item.label else "").encode('utf-8')
                  tmp_text_str = (item.text if item.text else "").encode('utf-8')
                  tmp_help_str = item.help.encode('utf-8') if item.help else None
                  list_items[indx].name = strdup(tmp_name_str) 
                  list_items[indx].text = strdup(tmp_text_str)
                  list_items[indx].help = strdup(tmp_help_str) if tmp_help_str else <char*>NULL
                  list_items[indx].state = item.state
                  
            if self.width is None:
                  self.width = len(self.title) + 10

            if self.list_height is None:
                  self.list_height = len(self.list_items)
            if self.list_height > self.height:
                  self.list_height = max(self.height - 5, 1)
                  
            defs.init_dialog(defs.dialog_state.input, defs.dialog_state.output)
            result = defs.dlg_checklist(self.title.encode('utf-8'),
                                        self.prompt.encode('utf-8'),
                                        self.height, self.width, self.list_height,
                                        len(self.list_items),
                                        list_items, <char*>NULL,
                                        defs.FLAG_RADIO if self._radio else defs.FLAG_CHECK,
                                        &current_choice)
            defs.end_dialog()

            rv = []
            for i in range(len(self.list_items)):
                  if list_items[i].state:
                        tnam = list_items[i].name
                        ttxt = list_items[i].text
                        thlp = list_items[i].help
                        rv.append(ListItem(tnam.decode('utf-8') if tnam else None,
                                           ttxt.decode('utf-8') if ttxt else None,
                                           help=thlp.decode('utf-8') if thlp else None,
                                           state=True))
                  free(list_items[i].name)
                  free(list_items[i].text)
                  free(list_items[i].help)
            free(list_items)
                                                
            if result == defs.DLG_EXIT_OK:
                  self._result = rv
            elif result == defs.DLG_EXIT_CANCEL:
                  self._result = None
            elif result == defs.DLG_EXIT_ESC:
                  raise DialogEscape
            else:
                  raise DialogError(code=result, message="Unknown return value")

      @property
      def result(self):
            if self._result is None:
                  self.run()
            return self._result

class RadioList(CheckList):
      def __init__(self, title, prompt, **kwargs):
            super(RadioList, self).__init__(title, prompt, **kwargs)
            self._radio = True
            self.list_height = kwargs.pop("list_height", None)
            self.list_items = kwargs.pop("list_items", None)

class Form(Dialog):
      def __init__(self, title, prompt, **kwargs):
            super(Form, self).__init__(title, prompt, **kwargs)
            self.form_height = kwargs.pop("form_height", None)
            self.form_items = kwargs.pop("form_items", None)
            
      @property
      def form_height(self):
            return self._form_height
      @form_height.setter
      def form_height(self, h):
            self._form_height = h
      @property
      def form_items(self):
            return self._items
      @form_items.setter
      def form_items(self, f):
            self._items = f

      def run(self):
            if not self.form_items:
                  raise ValueError("Form items must contain values")

            cdef defs.DIALOG_FORMITEM *form_items
            cdef defs.DIALOG_FORMITEM *packed_item
            cdef int choice
            cdef defs.DIALOG_FORMITEM ci
            cdef FormItem fiLoopValue
            
            form_items = <defs.DIALOG_FORMITEM*>calloc(len(self.form_items) + 1, sizeof(defs.DIALOG_FORMITEM))
                  
            base_y = 1
            # We're going to cycle through the items to find the maximum label length
            max_label = 0
            for fiLoopValue in self.form_items:
                  if len(fiLoopValue.label.label) > max_label:
                        max_label = len(fiLoopValue.label.label)
                        
            for indx, fiLoopValue in enumerate(self.form_items):
                  temp_value = fiLoopValue.Pack()
                  packed_item = <defs.DIALOG_FORMITEM*><char*>temp_value
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

            if self.width is None:
                  self.width = len(self.title) + 10

            if self.form_height is None:
                  self.form_height = len(self.form_items)
            if self.form_height > self.height:
                  self.form_height = max(self.height - 5, 1)

            defs.init_dialog(defs.stdin, defs.stdout)
            defs.dlg_put_backtitle()
            defs.dlg_parse_bindkey("formfield TAB FORM_NEXT".encode('utf-8'))
            defs.dlg_parse_bindkey("formfield DOWN FORM_NEXT".encode('utf-8'))
            defs.dlg_parse_bindkey("formfield UP FORM_PREV".encode('utf-8'))
            defs.dlg_parse_bindkey("formbox TAB FORM_NEXT".encode('utf-8'))
            defs.dlg_parse_bindkey("formbox DOWN FORM_NEXT".encode('utf-8'))
            defs.dlg_parse_bindkey("formbox UP FORM_PREV".encode('utf-8'))
            defs.dialog_state.visit_items = True
            defs.dialog_state.visit_cols = 1
            defs.dialog_vars.insecure = 1
            defs.dialog_vars.default_button = -1
            
            result = defs.dlg_form(self.title.encode('utf-8'),
                                   self.prompt.encode('utf-8'),
                                   self.height, self.width, self.form_height,
                                   len(self.form_items),
                                   form_items, &choice)
            defs.end_dialog()
            
            rv = []
            for indx in range(len(self.form_items)):
                  rv.append(UnpackFormItem(&form_items[indx]))
                  if form_items[indx].name_free:
                        free(form_items[indx].name)
                  if form_items[indx].text_free:
                        free(form_items[indx].text)
                  if form_items[indx].help and form_items[indx].help_free:
                        free(form_items[indx].help)

            free(form_items)

            if result == defs.DLG_EXIT_OK:
                  self._result = rv
            elif result == defs.DLG_EXIT_CANCEL:
                  self._result = None
            elif result == defs.DLG_EXIT_ESC:
                  raise DialogEscape
            else:
                  raise DialogError(code=result, message="Unknown return value")

      @property
      def result(self):
            if self._result is None:
                  self.run()
            return self._result
      

