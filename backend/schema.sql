PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS intersections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  location TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'maintenance')),
  current_mode_code TEXT NOT NULL DEFAULT 'AUTO',
  active_phase_plan_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (active_phase_plan_id) REFERENCES phase_plans(id)
);

CREATE TABLE IF NOT EXISTS road_approaches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  intersection_id INTEGER NOT NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (intersection_id, code),
  FOREIGN KEY (intersection_id) REFERENCES intersections(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS signal_heads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  road_approach_id INTEGER NOT NULL,
  code TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'vehicle' CHECK (type IN ('vehicle', 'pedestrian')),
  red_pin INTEGER,
  yellow_pin INTEGER,
  green_pin INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (road_approach_id, code),
  FOREIGN KEY (road_approach_id) REFERENCES road_approaches(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS traffic_modes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  priority_level INTEGER NOT NULL DEFAULT 1,
  description TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS phase_plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  intersection_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (intersection_id) REFERENCES intersections(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS phase_steps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phase_plan_id INTEGER NOT NULL,
  code TEXT NOT NULL,
  sequence_no INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 1),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (phase_plan_id, code),
  UNIQUE (phase_plan_id, sequence_no),
  FOREIGN KEY (phase_plan_id) REFERENCES phase_plans(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS phase_signal_states (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phase_step_id INTEGER NOT NULL,
  signal_head_id INTEGER NOT NULL,
  light_color TEXT NOT NULL CHECK (light_color IN ('RED', 'YELLOW', 'GREEN', 'OFF')),
  UNIQUE (phase_step_id, signal_head_id),
  FOREIGN KEY (phase_step_id) REFERENCES phase_steps(id) ON DELETE CASCADE,
  FOREIGN KEY (signal_head_id) REFERENCES signal_heads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS conflict_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  intersection_id INTEGER NOT NULL,
  source_approach_id INTEGER NOT NULL,
  target_approach_id INTEGER NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  UNIQUE (intersection_id, source_approach_id, target_approach_id),
  FOREIGN KEY (intersection_id) REFERENCES intersections(id) ON DELETE CASCADE,
  FOREIGN KEY (source_approach_id) REFERENCES road_approaches(id) ON DELETE CASCADE,
  FOREIGN KEY (target_approach_id) REFERENCES road_approaches(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS control_commands (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  intersection_id INTEGER NOT NULL,
  mode_code TEXT NOT NULL,
  command TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'mobile',
  created_by TEXT NOT NULL DEFAULT 'operator',
  status TEXT NOT NULL DEFAULT 'success' CHECK (status IN ('success', 'rejected')),
  message TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (intersection_id) REFERENCES intersections(id) ON DELETE CASCADE,
  FOREIGN KEY (mode_code) REFERENCES traffic_modes(code)
);

CREATE TABLE IF NOT EXISTS traffic_event_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  intersection_id INTEGER NOT NULL,
  mode_code TEXT NOT NULL,
  phase_code TEXT NOT NULL DEFAULT '',
  remaining_seconds INTEGER NOT NULL DEFAULT -1,
  status_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (intersection_id) REFERENCES intersections(id) ON DELETE CASCADE,
  FOREIGN KEY (mode_code) REFERENCES traffic_modes(code)
);

CREATE INDEX IF NOT EXISTS idx_road_approaches_intersection ON road_approaches(intersection_id);
CREATE INDEX IF NOT EXISTS idx_signal_heads_approach ON signal_heads(road_approach_id);
CREATE INDEX IF NOT EXISTS idx_phase_plans_intersection ON phase_plans(intersection_id);
CREATE INDEX IF NOT EXISTS idx_phase_steps_plan_sequence ON phase_steps(phase_plan_id, sequence_no);
CREATE INDEX IF NOT EXISTS idx_phase_signal_states_step ON phase_signal_states(phase_step_id);
CREATE INDEX IF NOT EXISTS idx_conflict_rules_intersection ON conflict_rules(intersection_id);
CREATE INDEX IF NOT EXISTS idx_control_commands_intersection_created ON control_commands(intersection_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_traffic_event_logs_intersection_created ON traffic_event_logs(intersection_id, created_at DESC);
