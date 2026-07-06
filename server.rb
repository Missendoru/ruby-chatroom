require 'socket'
require 'digest/sha1'
require 'securerandom'
require 'json'
require 'time'

PORT = 3000
$cc = {} 
$gg = {} 
$pp = {} 

def hs(io)
  r = ""
  while (l = io.gets) && l.strip != ""
    r << l
  end
  if r =~ /Sec-WebSocket-Key:\s*(.+)\r?\n/i
    k = $1.strip
    ak = Digest::SHA1.base64digest(k + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
    io.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{ak}\r\n\r\n")
    return true
  end
  false
end

def r_fr(io)
  fb = io.read(1)
  return nil if fb.nil?
  b1 = fb.unpack1('C')
  return :close if (b1 & 0x0F) == 8
  b2 = io.read(1).unpack1('C')
  m = (b2 & 0x80) != 0
  len = b2 & 0x7F
  if len == 126
    len = io.read(2).unpack1('n')
  elsif len == 127
    len = io.read(8).unpack1('Q>')
  end
  mk = io.read(4).unpack('C*') if m
  raw = io.read(len)
  return nil if raw.nil? || raw.bytesize < len
  p = raw.bytes
  p = p.each_with_index.map { |b, idx| b ^ mk[idx % 4] } if m
  p.pack('C*').force_encoding('UTF-8')
end

def w_fr(io, txt)
  b = txt.bytes
  len = b.length
  h = [0x81]
  if len <= 125
    h << len
  elsif len <= 65535
    h << 126
    h << [len].pack('n').bytes
  else
    h << 127
    h << [len].pack('Q>').bytes
  end
  io.write(h.flatten.pack('C*'))
  io.write(txt)
rescue
end

def tx_cl(io, data)
  w_fr(io, data.to_json)
end

def bcast(data, ex = nil)
  raw = data.to_json
  $cc.each_key do |s|
    next if $cc[s][:g_id]
    if data[:type] == 'chat'
      w_fr(s, raw)
    else
      w_fr(s, raw) if s != ex
    end
  end
end

def tx_g(g_id, data)
  g = $gg[g_id]
  return unless g
  tx_cl(g[:p1], data) if g[:p1]
  tx_cl(g[:p2], data) if g[:p2]
end

def kill_g(g_id)
  g = $gg[g_id]
  if g
    $cc[g[:p1]][:g_id] = nil if g[:p1] && $cc[g[:p1]]
    $cc[g[:p2]][:g_id] = nil if g[:p2] && $cc[g[:p2]]
    $gg.delete(g_id)
  end
end

def purge(s, man = false)
  return unless $cc[s]
  g_id = $cc[s][:g_id]
  return unless g_id
  tx_g(g_id, { type: 'system', message: "#{$cc[s][:name]} left the match." }) if man
  kill_g(g_id)
end

def mk_sea
  grid = Array.new(11) { Array.new(11, ' ') }
  fl = [['Carrier', 5], ['Battleship', 4], ['Cruiser', 3], ['Submarine', 3], ['Destroyer', 2]]
  fl.each do |_, sz|
    ok = false
    while !ok
      ori = rand(2)
      if ori == 0
        r, c = rand(0..10), rand(0..(11 - sz))
        unless (0...sz).any? { |i| grid[r][c + i] != ' ' }
          (0...sz).each { |i| grid[r][c + i] = 'S' }
          ok = true
        end
      else
        r, c = rand(0..(11 - sz)), rand(0..10)
        unless (0...sz).any? { |i| grid[r + i][c] != ' ' }
          (0...sz).each { |i| grid[r + i][c] = 'S' }
          ok = true
        end
      end
    end
  end
  grid
end

def view_sea(g1, g2)
  out = "         [YOUR FLEET]                       [TARGET RADIAL]\n"
  out << "   1 2 3 4 5 6 7 8 9 1011              1 2 3 4 5 6 7 8 9 1011\n"
  0.step(10) do |r|
    lbl = (r + 1).to_s.rjust(2)
    l_side = g1[r].map { |c| c == ' ' ? '.' : c }.join(" ")
    r_side = g2[r].map { |c| c == 'S' ? '.' : (c == ' ' ? '.' : c) }.join(" ")
    left_block = sprintf("%-31s", "#{lbl} #{l_side}")
    out << "#{left_block} |   #{lbl} #{r_side}\n"
  end
  out
end

def setup_g(t, p1, p2)
  n1, n2 = $cc[p1][:name], $cc[p2][:name]
  case t
  when 'ttt'
    { type: 'ttt', p1: p1, p2: p2, turn: p1, board: Array.new(9, ' '), syms: { n1 => 'X', n2 => 'O' } }
  when 'rps'
    { type: 'rps', p1: p1, p2: p2, moves: {} }
  when 'battle'
    { type: 'battle', p1: p1, p2: p2, turn: p1, st: { n1 => { hp: 100, max: 100, it: 2, df: false }, n2 => { hp: 100, max: 100, it: 2, df: false } } }
  when 'sea'
    { type: 'sea', p1: p1, p2: p2, turn: p1, grids: { p1 => mk_sea, p2 => mk_sea }, left: { p1 => 17, p2 => 17 }, rdy: { p1 => false, p2 => false } }
  end
end

def draw_g(g_id)
  g = $gg[g_id]
  return unless g
  n1, n2 = $cc[g[:p1]][:name], $cc[g[:p2]][:name]
  tn = $cc[g[:turn]][:name] if g[:turn]

  if g[:type] == 'ttt'
    b = g[:board]
    grid = "\n  #{b[0]} | #{b[1]} | #{b[2]}     [1][2][3]\n ---+---+---\n  #{b[3]} | #{b[4]} | #{b[5]}     [4][5][6]\n ---+---+---\n  #{b[6]} | #{b[7]} | #{b[8]}     [7][8][9]\n\nTurn: #{tn} (#{g[:syms][tn]}). Move: /move [1-9]"
    tx_g(g_id, { type: 'game', message: grid })
  elsif g[:type] == 'rps'
    tx_g(g_id, { type: 'game', message: "choose your weapon commands: /rock, /paper, /scissors" })
  elsif g[:type] == 'battle'
    s = g[:st]
    hud = "\n arena status:\n[#{n1}] hp: #{s[n1][:hp]}/#{s[n1][:max]} | potions: #{s[n1][:it]} #{s[n1][:df] ? 'defending' : ''}\n[#{n2}] hp: #{s[n2][:hp]}/#{s[n2][:max]} | potions: #{s[n2][:it]} #{s[n2][:df] ? 'defending️' : ''}\n\n current turn: #{tn}. commands: /attack, /defend, /item"
    tx_g(g_id, { type: 'game', message: hud })
  elsif g[:type] == 'sea'
    p1, p2 = g[:p1], g[:p2]
    rdy_all = g[:rdy][p1] && g[:rdy][p2]
    [p1, p2].each do |ps|
      os = (ps == p1) ? p2 : p1
      v = view_sea(g[:grids][ps], g[:grids][os])
      if rdy_all
        m = "\nAll set! Battle starting.\nopponent ships remaining: #{g[:left][os]}/17\nturn: #{tn}. command: /fire [1-11] [1-11]"
      else
        m = "\n[Pre-Game Setup]\nyour Status: #{g[:rdy][ps] ? 'READY' : 'NOT READY'} | opponent Status: #{g[:rdy][os] ? 'READY' : 'NOT READY'}\nactions: \ntype `/reroll` to shuffle your ships, or `/ready` once you're ready."
      end
      tx_cl(ps, { type: 'game', message: v + m })
    end
  end
end

def c_ttt(b)
  [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]].any? { |x, y, z| b[x] != ' ' && b[x] == b[y] && b[x] == b[z] }
end

def p_mv(s, cmd, args)
  g_id = $cc[s][:g_id]
  g = $gg[g_id]
  return unless g
  me = $cc[s][:name]
  os = (g[:p1] == s) ? g[:p2] : g[:p1]
  opp = $cc[os][:name]

  if g[:type] == 'ttt'
    return tx_cl(s, { type: 'system', message: 'use /move [1-9]' }) if cmd != 'move'
    return tx_cl(s, { type: 'system', message: "it's not your turn" }) if g[:turn] != s
    idx = args[0].to_i - 1
    return tx_cl(s, { type: 'system', message: 'invalid square selection' }) if idx < 0 || idx > 8 || g[:board][idx] != ' '
    g[:board][idx] = g[:syms][me]
    if c_ttt(g[:board])
      draw_g(g_id)
      tx_g(g_id, { type: 'game', message: "#{me} wins =)" })
      return kill_g(g_id)
    elsif !g[:board].include?(' ')
      draw_g(g_id)
      tx_g(g_id, { type: 'game', message: "it's a draw !" })
      return kill_g(g_id)
    end
    g[:turn] = os
    draw_g(g_id)

  elsif g[:type] == 'rps'
    return tx_cl(s, { type: 'system', message: 'choose: /rock, /paper, or /scissors' }) unless ['rock', 'paper', 'scissors'].include?(cmd)
    return tx_cl(s, { type: 'system', message: 'you already locked in a choice' }) if g[:moves][me]
    g[:moves][me] = cmd
    tx_cl(s, { type: 'system', message: "you selected #{cmd}. waiting on opponent..." })
    if g[:moves][me] && g[:moves][opp]
      m1, m2 = g[:moves][$cc[g[:p1]][:name]], g[:moves][$cc[g[:p2]][:name]]
      res = "#{$cc[g[:p1]][:name]} threw #{m1}. #{$cc[g[:p2]][:name]} threw #{m2}.\n"
      if m1 == m2
        g[:moves] = {}
        tx_g(g_id, { type: 'game', message: res + " tie game! re-shuffling turns..." })
      elsif (m1=='rock'&&m2=='scissors') || (m1=='paper'&&m2=='rock') || (m1=='scissors'&&m2=='paper')
        tx_g(g_id, { type: 'game', message: res + "#{$cc[g[:p1]][:name]} wins" })
        kill_g(g_id)
      else
        tx_g(g_id, { type: 'game', message: res + "#{$cc[g[:p2]][:name]} wins" })
        kill_g(g_id)
      end
    end

  elsif g[:type] == 'battle'
    return tx_cl(s, { type: 'system', message: 'actions: /attack, /defend, /item' }) unless ['attack', 'defend', 'item'].include?(cmd)
    return tx_cl(s, { type: 'system', message: "it's not your turn !!" }) if g[:turn] != s
    g[:st][me][:df] = false
    log = ""
    if cmd == 'attack'
      dmg = rand(10..25)
      if g[:st][opp][:df]
        dmg = (dmg / 2).floor
        log = "#{me} attacks #{opp} mitigates impact with defense. Taken #{dmg} dmg!"
      else
        log = "#{me} hits #{opp} across the board for #{dmg} dmg!"
      end
      g[:st][opp][:hp] = [0, g[:st][opp][:hp] - dmg].max
    elsif cmd == 'defend'
      g[:st][me][:df] = true
      log = "#{me} begins defending!"
    elsif cmd == 'item'
      return tx_cl(s, { type: 'system', message: 'no health potions left!' }) if g[:st][me][:it] <= 0
      g[:st][me][:it] -= 1
      g[:st][me][:hp] = [g[:st][me][:max], g[:st][me][:hp] + 30].min
      log = "#{me} consumes a potion, processing 30 HP!"
    end
    tx_g(g_id, { type: 'game', message: log })
    if g[:st][opp][:hp] <= 0
      tx_g(g_id, { type: 'game', message: "#{opp} collapsed! \n #{me} wins the battle match!" })
      return kill_g(g_id)
    end
    g[:turn] = os
    draw_g(g_id)

  elsif g[:type] == 'sea'
    all_ok = g[:rdy][g[:p1]] && g[:rdy][g[:p2]]
    if cmd == 'reroll'
      return tx_cl(s, { type: 'system', message: 'cannot reroll your fleet as you have declared yourself as ready' }) if g[:rdy][s]
      g[:grids][s] = mk_sea
      return draw_g(g_id)
    elsif cmd == 'ready'
      g[:rdy][s] = true
      tx_g(g_id, { type: 'system', message: "#{me} is ready!" })
      return draw_g(g_id)
    end
    return tx_cl(s, { type: 'system', message: 'combat weapons offline. both players must be `/ready` first!' }) unless all_ok
    return tx_cl(s, { type: 'system', message: 'use /fire [row] [col]' }) if cmd != 'fire'
    return tx_cl(s, { type: 'system', message: "it's not your turn" }) if g[:turn] != s
    r, c = args[0].to_i - 1, args[1].to_i - 1
    return tx_cl(s, { type: 'system', message: 'coordinates out of bounds! Choose [1-11]' }) if r < 0 || r > 10 || c < 0 || c > 10
    state = g[:grids][os][r][c]
    return tx_cl(s, { type: 'system', message: 'there has already been fire at that spot' }) if state == 'H' || state == 'M'
    if state == 'S'
      g[:grids][os][r][c] = 'H'
      g[:left][os] -= 1
      tx_g(g_id, { type: 'game', message: "hit !! #{me} has struck #{opp} (#{r+1}, #{c+1})" })
    else
      g[:grids][os][r][c] = 'M'
      tx_g(g_id, { type: 'game', message: "miss !! #{me} fired into open water (#{r+1}, #{c+1})" })
    end
    if g[:left][os] <= 0
      tx_g(g_id, { type: 'game', message: "victory !! #{me} has fully sunk #{opp}'s fleet!" })
      return kill_g(g_id)
    end
    g[:turn] = os
    draw_g(g_id)
  end
end

def h_cmd(s, raw)
  args = raw.strip.split(' ')
  cmd = args.shift.downcase
  return tx_cl(s, { type: 'system', message: "--- prompts ---\n/help - show options\n/name [handle] - change profile ID\n/players - list users\n/play [handle] [ttt|rps|battle|sea] - request match\n/accept - accept pending request\n/decline - decline pending request\n/clear - clear client history terminal\n/quit - drop current game" }) if cmd == 'help'
  return tx_cl(s, { type: 'clear' }) if cmd == 'clear'
  if cmd == 'name' && args[0]
    old = $cc[s][:name]
    $cc[s][:name] = args[0][0..11]
    tx_cl(s, { type: 'save_profile', username: $cc[s][:name] })
    return bcast({ type: 'system', message: "#{old} ID changed to #{$cc[s][:name]}." })
  end
  if cmd == 'players'
    lby, act = [], []
    $cc.values.each { |c| c[:g_id] ? act << c[:name] : lby << c[:name] }
    return tx_cl(s, { type: 'system', message: "--- Connected Users ---\nnot playing: #{lby.empty? ? 'None' : lby.join(', ')}\nplaying: #{act.empty? ? 'None' : act.join(', ')}" })
  end
  if cmd == 'play'
    t_name = args[0]
    gt = args[1] ? args[1].downcase : nil
    return tx_cl(s, { type: 'system', message: 'usage: /play [user] [ttt | rps | battle | sea]' }) unless ['ttt','rps','battle','sea'].include?(gt)
    return tx_cl(s, { type: 'system', message: 'clear existing game states first with /quit' }) if $cc[s][:g_id]
    t_sock = $cc.find { |_, v| v[:name] == t_name }&.first
    return tx_cl(s, { type: 'system', message: 'user target lookup failure.' }) if !t_sock || t_sock == s
    return tx_cl(s, { type: 'system', message: "#{t_name} is currently in a match" }) if $cc[t_sock][:g_id]
    $pp[t_sock] = { challenger: s, type: gt }
    tx_cl(s, { type: 'system', message: "match request sent to #{t_name}, waiting for handshake..." })
    return tx_cl(t_sock, { type: 'system', message: " #{$cc[s][:name]} wants to play #{gt.upcase} with you. \n type `/accept` or `/decline`" })
  end
  if cmd == 'accept'
    ch = $pp.delete(s)
    return tx_cl(s, { type: 'system', message: 'no pending match requests found' }) unless ch
    cs = ch[:challenger]
    return tx_cl(s, { type: 'system', message: 'player has disconnected or joined another room' }) if !$cc[cs] || $cc[cs][:g_id]
    g_id = "game_#{SecureRandom.hex(4)}"
    $cc[s][:g_id] = $cc[cs][:g_id] = g_id
    $gg[g_id] = setup_g(ch[:type], cs, s)
    tx_g(g_id, { type: 'game', message: "Session bound: #{$cc[cs][:name]} vs #{$cc[s][:name]}!" })
    return draw_g(g_id)
  end
  if cmd == 'decline'
    ch = $pp.delete(s)
    return tx_cl(s, { type: 'system', message: 'No pending match requests found.' }) unless ch
    cs = ch[:challenger]
    tx_cl(cs, { type: 'system', message: "#{$cc[s][:name]} declined your match request." }) if cs && $cc[cs]
    return tx_cl(s, { type: 'system', message: 'request successfully declined' })
  end
  if cmd == 'quit'
    return tx_cl(s, { type: 'system', message: 'no current session running.' }) unless $cc[s][:g_id]
    return purge(s, true)
  end
  $cc[s][:g_id] ? p_mv(s, cmd, args) : tx_cl(s, { type: 'system', message: 'idk what that is bro' })
end

Thread.new do
  srv = TCPServer.new('0.0.0.0', PORT)
  loop do
    Thread.start(srv.accept) do |ses|
      begin
        req = ses.gets
        next unless req
        path = req.split(' ')[1]
        if path == '/' || path == '/index.html'
          fc = File.read(File.join(__dir__, 'index.html'))
          ses.print "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{fc.bytesize}\r\nConnection: close\r\n\r\n"
          ses.print fc
        else
          ses.print "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        end
      rescue => e; puts "HTTP error: #{e.message}"
      ensure; ses.close rescue nil; end
    end
  end
end

ws = TCPServer.new('0.0.0.0', 3001)
puts "online !!!!! \nhosted at port #{PORT}"

loop do
  Thread.start(ws.accept) do |s|
    begin
      if hs(s)
        $cc[s] = { name: "Guest_#{rand(1000..9999)}", g_id: nil, pfp: nil }
        tx_cl(s, { type: 'system', message: "handshake verified. use /help for options" })
        bcast({ type: 'system', message: "#{$cc[s][:name]} connected." }, s)
        loop do
          pld = r_fr(s)
          break if pld.nil? || pld == :close
          begin
            psd = JSON.parse(pld)
            if psd['type'] == 'sync_profile'
              $cc[s][:name] = psd['username'][0..11] if psd['username']
              $cc[s][:pfp] = psd['pfp'] if psd['pfp']
              next
            end
            if psd['type'] == 'chat'
              g_id = $cc[s][:g_id]
              pay = { type: 'chat', from: $cc[s][:name], pfp: $cc[s][:pfp], message: psd['message'], timestamp: Time.now.iso8601 }
              g_id ? tx_g(g_id, pay) : bcast(pay, s)
            elsif psd['type'] == 'command'
              h_cmd(s, psd['command'])
            end
          rescue => e; puts "Error handling dynamic payload: #{e.message}"; end
        end
      end
    rescue => e; puts "Connection processing error: #{e.message}"
    ensure
      $pp.delete(s)
      if $cc[s]
        bcast({ type: 'system', message: "#{$cc[s][:name]} disconnected" })
        purge(s)
        $cc.delete(s)
      end
      s.close rescue nil
    end
  end
end