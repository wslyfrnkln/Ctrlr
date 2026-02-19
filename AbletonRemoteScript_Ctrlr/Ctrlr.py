import Live
from _Framework.ControlSurface import ControlSurface
from _Framework.ButtonElement import ButtonElement
from _Framework.EncoderElement import EncoderElement
from _Framework.TransportComponent import TransportComponent
from _Framework.MixerComponent import MixerComponent
from _Framework.InputControlElement import MIDI_NOTE_TYPE, MIDI_CC_TYPE

# MIDI channel (0-indexed, so 0 = Channel 1)
CH = 0

# These must match the values in iOS AppModel.swift and ContentView.swift
PLAY_NOTE   = 60   # C4
STOP_NOTE   = 62   # D4
RECORD_NOTE = 64   # E4
LOOP_CC     = 66
VOLUME_CC   = 7    # Selected track volume (absolute)
ARM_CC      = 65   # Selected track arm toggle


class Ctrlr(ControlSurface):

    def __init__(self, c_instance):
        super(Ctrlr, self).__init__(c_instance)
        with self.component_guard():
            self._setup_transport()
            self._setup_mixer()

    # Ableton auto-selects this port name in the MIDI preferences,
    # matching the virtual source CtrlrHelper creates via MIDISourceCreate.
    def suggest_input_port(self):
        return 'Ctrlr'

    def suggest_output_port(self):
        return ''

    def _setup_transport(self):
        transport = TransportComponent()
        # is_momentary=True: fires on Note/CC value >= 64 (i.e. Note On / CC 127)
        transport.set_play_button(
            ButtonElement(True, MIDI_NOTE_TYPE, CH, PLAY_NOTE))
        transport.set_stop_button(
            ButtonElement(True, MIDI_NOTE_TYPE, CH, STOP_NOTE))
        transport.set_record_button(
            ButtonElement(True, MIDI_NOTE_TYPE, CH, RECORD_NOTE))
        transport.set_loop_button(
            ButtonElement(True, MIDI_CC_TYPE, CH, LOOP_CC))

    def _setup_mixer(self):
        mixer = MixerComponent(1)
        # Absolute CC fader → selected track volume
        mixer.channel_strip(0).set_volume_control(
            EncoderElement(MIDI_CC_TYPE, CH, VOLUME_CC,
                           Live.MidiMap.MapMode.absolute))
        # CC toggle → selected track arm
        mixer.channel_strip(0).set_arm_button(
            ButtonElement(True, MIDI_CC_TYPE, CH, ARM_CC))

    def disconnect(self):
        super(Ctrlr, self).disconnect()
