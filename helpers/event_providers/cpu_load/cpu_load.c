#include "cpu.h"
#include "../sketchybar.h"
#include <sys/sysctl.h>

// Memory in use, as a percentage: the same number `memory_pressure` reports as
// 100 - "System-wide memory free percentage", read without spawning a process.
static int mem_used_pct(void) {
  int level = 0;
  size_t len = sizeof(level);
  if (sysctlbyname("kern.memorystatus_level", &level, &len, NULL, 0) != 0) return -1;
  return 100 - level;
}

static double mem_total_gb(void) {
  uint64_t bytes = 0;
  size_t len = sizeof(bytes);
  if (sysctlbyname("hw.memsize", &bytes, &len, NULL, 0) != 0) return 0;
  return bytes / 1073741824.0;
}

int main (int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);
  struct cpu cpu;
  cpu_init(&cpu);

  // Setup the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  double total_gb = mem_total_gb();
  char trigger_message[512];
  for (;;) {
    // Acquire new info
    cpu_update(&cpu);

    // Prepare the event message
    snprintf(trigger_message,
             512,
             "--trigger '%s' user_load='%d' sys_load='%02d' total_load='%02d'"
             " mem_used='%d' mem_total_gb='%.0f'",
             argv[1],
             cpu.user_load,
             cpu.sys_load,
             cpu.total_load,
             mem_used_pct(),
             total_gb                                              );

    // Trigger the event
    sketchybar(trigger_message);

    // Wait
    usleep(update_freq * 1000000);
  }
  return 0;
}
