#!/bin/bash
# Force fcitx5 to English (inactive) whenever the session is about to become
# a password prompt, covering the paths the Super+L wrapper cannot:
#   - idle timeout lock, lid close, system menu "Lock", loginctl lock-session
#   - suspend/hibernate initiated by anything at all
#
# GNOME Shell's "disable input method on password entry" logic is hardcoded
# against IBus and does nothing for fcitx5, so without this the lock screen
# inherits whatever Rime state was last active and echoes pinyin in the
# password field.

reset_to_english() {
    fcitx5-remote -c
    # fcitx5-remote -c is a silent no-op when no input context has focus,
    # so record what actually stuck rather than trusting the call.
    #   1 = inactive (English, what we want)
    #   2 = active (Chinese, the bug)
    #   empty = the call went nowhere at all
    sleep 0.3
    echo "  -> fcitx5-remote reports: $(fcitx5-remote)"
}

# gnome-shell emits ActiveChanged(true) the moment the lock curtain goes up,
# regardless of what triggered it.
watch_screensaver() {
    gdbus monitor --session --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver 2>&1 |
    while read -r line; do
        case "$line" in
            *"ActiveChanged (true"*)
                echo "[lock] screen locking -> forcing English"
                reset_to_english
                ;;
        esac
    done
}

# logind emits PrepareForSleep(true) before suspending. This comes from the
# system bus, so it still fires even when gnome-shell's lock path stalls.
watch_logind() {
    gdbus monitor --system --dest org.freedesktop.login1 \
        --object-path /org/freedesktop/login1 2>&1 |
    while read -r line; do
        case "$line" in
            *"PrepareForSleep (true"*)
                echo "[sleep] system suspending -> forcing English"
                reset_to_english
                ;;
        esac
    done
}

watch_screensaver &
watch_logind &

# If either watcher dies we are silently running at half coverage, so bail out
# and let systemd restart the whole thing.
wait -n
echo "a bus monitor exited, restarting" >&2
exit 1
