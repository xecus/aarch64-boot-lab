# run-*.sh / dump-dtb.sh から読み込み（source）、第1引数で QEMU の -cpu を選ぶ。
# 省略すると cortex-a53。"a55" のように cortex- を省いてもよい。
#   ./run-direct-6.18.sh            → cortex-a53
#   ./run-direct-6.18.sh a76        → cortex-a76

# 使える CPU（左から ARMv8.0 小コア / v8.2 小コア / v8.0 大コア / v8.2 大コア / v9.0）
CPUS="cortex-a53 cortex-a55 cortex-a72 cortex-a76 cortex-a710"

CPU=${1:-cortex-a53}
case "$CPU" in
    cortex-*) ;;
    *) CPU=cortex-$CPU ;;
esac

case " $CPUS " in
    *" $CPU "*) ;;
    *)
        echo "使い方: $0 [CPU]" >&2
        echo "CPU: $CPUS（省略すると cortex-a53）" >&2
        exit 1
        ;;
esac
