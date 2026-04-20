function love.conf(t)
  t.version = "11.5"
  t.identity = "AFCServer"

  t.window.title = "AFCServer"
  t.window.x = 10
  t.window.y = 30
  t.window.width = 500
  t.window.height = 300

  --disable unneeded love2d functions
  t.accelerometerjoystick = false
  t.modules.physics = false
  t.modules.touch = false
  t.modules.audio = false

  t.console = true
end