# run.sh / dump-dtb.sh から読み込み（source）、QEMU の -cpu に渡す CPU を選ぶ。
#   select_cpu a76    → CPU=cortex-a76
#   select_cpu ""     → CPU=cortex-a53（省略時）
# "a55" のように cortex- を省いてもよい。一覧にない名前なら 1 を返す。

# 使える CPU（左から ARMv8.0 小コア / v8.2 小コア / v8.0 大コア / v8.2 大コア / v9.0）
CPUS="cortex-a53 cortex-a55 cortex-a72 cortex-a76 cortex-a710"

select_cpu() {
    CPU=${1:-cortex-a53}
    case "$CPU" in
        cortex-*) ;;
        *) CPU=cortex-$CPU ;;
    esac

    case " $CPUS " in
        *" $CPU "*) return 0 ;;
    esac
    echo "CPU が不正です: $1（使える CPU: $CPUS）" >&2
    return 1
}
