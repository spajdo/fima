main() {
    case "$1" in
        start)
            start
            ;;
        stop|kill|exit)
            stop
            ;;
        status)
            status
            ;;
        update)
            update
            ;;
        *)
            echo "Usage: $0 {start|stop|kill|exit|status|update}"
            echo "Running default 'start'"
            start
            ;;
    esac
}

start() {
    echo "Starting..."
}

stop() {
    echoError "Stop not supported!!!"
}

status() {
    echoError "Status not supported!!!"
}

update() {
    echoError "Update not supported!!!"
}

# remove 'exit' if not want to close terminal, use 'exec $SHELL' for testing purpose if you want to have terminal open when script is done
main "$@"; exit
# main "$@"
# exec $SHELL