# c00lgui v5 - panel lanzador con skins de asistentes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# el panel mide su propio escalado de pantalla para que nada se corte
try {
    Add-Type -Namespace C00l -Name Dpi -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][C00l.Dpi]::SetProcessDPIAware()
} catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()
# caja del bocadillo: puede recibir la rueda del ratón para leer textos largos
try {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
public class CajaTexto : System.Windows.Forms.Panel {
    public CajaTexto() {
        SetStyle(System.Windows.Forms.ControlStyles.Selectable | System.Windows.Forms.ControlStyles.SupportsTransparentBackColor | System.Windows.Forms.ControlStyles.OptimizedDoubleBuffer | System.Windows.Forms.ControlStyles.AllPaintingInWmPaint | System.Windows.Forms.ControlStyles.UserPaint, true);
        TabStop = false;
    }
}
'@
} catch {}

# TAMAÑO DEL PANEL: 1.0 = normal, 1.2 = un poco más grande, 1.5 = grande
$Tamano = 1.2
$gDpi = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$script:dpiBase = $gDpi.DpiX / 96.0
$script:K = [float]($script:dpiBase * $Tamano)
$gDpi.Dispose()
# fuentes en píxeles: Fnt para controles (ya escalada), FntP para dibujos (los escala ScaleTransform)
function Fnt($a) {
    $st = if ($a.Count -ge 3) { $a[2] } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font((Familia ([string]$a[0])), [float]($a[1] * 96 / 72 * $script:K), $st, [System.Drawing.GraphicsUnit]::Pixel)
}
function FntP($a) {
    $st = if ($a.Count -ge 3) { $a[2] } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font((Familia ([string]$a[0])), [float]($a[1] * 96 / 72), $st, [System.Drawing.GraphicsUnit]::Pixel)
}
# fuentes que vienen con las skins (las de Mewgenics) o las de Windows
$script:fuentesPriv = @{}
function Familia($n) {
    if ($script:fuentesPriv.ContainsKey($n)) { return $script:fuentesPriv[$n] }
    try { return (New-Object System.Drawing.FontFamily($n)) } catch { return [System.Drawing.FontFamily]::GenericSansSerif }
}
function Escalar($ctl) { $ctl.Scale((New-Object System.Drawing.SizeF($script:K, $script:K))) }
# cualquier error interno se convierte en un glitch/mensaje del panel en vez de una ventana de error
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)

$Raiz = $PSScriptRoot
$script:pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($ttf in @('skins\kaijus\edmund.ttf', 'skins\kaijus\tika.ttf')) { $r = Join-Path $Raiz $ttf; if (Test-Path $r) { try { $script:pfc.AddFontFile($r) } catch {} } }
foreach ($fam in $script:pfc.Families) { $script:fuentesPriv[$fam.Name] = $fam; $script:fuentesPriv[($fam.Name -replace ' Regular$', '')] = $fam }
$ArchivoSkin = Join-Path $Raiz 'skin.txt'
$Rnd = New-Object System.Random
$script:dia = (Get-Date).DayOfYear

# ================= AJUSTES (se guardan en ajustes.txt) =================
$ArchivoAjustes = Join-Path $Raiz 'ajustes.txt'
$script:aj = [ordered]@{
    Sonido = $true; Volumen = 100; Invitados = $true; Intros = $true; Charla = 'normal'
    Encima = $false; Tamano = [double]$Tamano; Opacidad = 100; Posicion = $true; Inicio = $false; X = ''; Y = ''
    Guia = $false   # si ya se ha visto la guía del panda
    Epilepsia = $false   # modo seguro: sin destellos, parpadeos, temblores ni intros (ver Sin-Destellos)
}
function Cargar-Ajustes {
    if (-not (Test-Path $ArchivoAjustes)) { return }
    foreach ($l in (Get-Content $ArchivoAjustes -Encoding UTF8)) {
        if ($l -notmatch '^\s*(\w+)\s*=\s*(.*)$') { continue }
        $c = $Matches[1]; $v = $Matches[2].Trim()
        if (-not $script:aj.Contains($c)) { continue }
        $act = $script:aj[$c]
        if ($act -is [bool]) { $script:aj[$c] = ($v -eq 'si') }
        elseif ($act -is [int]) { $n = 0; if ([int]::TryParse($v, [ref]$n)) { $script:aj[$c] = $n } }
        elseif ($act -is [double]) { $d = 0.0; if ([double]::TryParse($v, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { $script:aj[$c] = $d } }
        else { $script:aj[$c] = $v }
    }
}
function Guardar-Ajustes {
    $l = foreach ($c in $script:aj.Keys) {
        $v = $script:aj[$c]
        if ($v -is [bool]) { $v = $(if ($v) { 'si' } else { 'no' }) } elseif ($v -is [double]) { $v = $v.ToString([Globalization.CultureInfo]::InvariantCulture) }
        "$c = $v"
    }
    try { Set-Content -Path $ArchivoAjustes -Value $l -Encoding UTF8 } catch {}
}
Cargar-Ajustes
$script:K = [float]($script:dpiBase * $script:aj.Tamano)

# ================= BOTONES =================
# Estos son los botones de serie. Cada persona puede cambiar el orden y añadir los suyos desde el panel
# (Ajustes > Editar botones): se guardan en botones.txt y, si ese archivo existe, se usan en vez de esta lista.
# Nombre = texto del botón | Abrir = programa, archivo, carpeta o URL | Web = (opcional) URL si el programa no está instalado
$BotonesDeSerie = @(
    @{ Nombre = 'YouTube';       Abrir = 'https://www.youtube.com' }
    @{ Nombre = 'Word';          Abrir = 'winword.exe';  Web = 'https://www.office.com/launch/word' }
    @{ Nombre = 'Excel';         Abrir = 'excel.exe';    Web = 'https://www.office.com/launch/excel' }
    @{ Nombre = 'PowerPoint';    Abrir = 'powerpnt.exe'; Web = 'https://www.office.com/launch/powerpoint' }
    @{ Nombre = 'Outlook';       Abrir = 'outlook.exe';  Web = 'https://outlook.live.com' }
    @{ Nombre = 'OneNote';       Abrir = 'onenote.exe';  Web = 'https://www.onenote.com/notebooks' }
    @{ Nombre = 'Access';        Abrir = 'msaccess.exe' }
    @{ Nombre = 'Publisher';     Abrir = 'mspub.exe' }
    @{ Nombre = 'Teams';         Abrir = 'ms-teams:';    Web = 'https://teams.microsoft.com' }
    @{ Nombre = 'OneDrive';      Abrir = 'https://onedrive.live.com' }
    @{ Nombre = 'Office Web';    Abrir = 'https://www.office.com' }
    @{ Nombre = 'Bloc de notas'; Abrir = 'notepad.exe' }
    @{ Nombre = 'Calculadora';   Abrir = 'calc.exe' }
    @{ Nombre = 'Explorador';    Abrir = 'explorer.exe' }
    @{ Nombre = 'CMD';           Abrir = 'cmd.exe' }
    @{ Nombre = 'GitHub';        Abrir = 'https://github.com' }
    @{ Nombre = 'Wikipedia';     Abrir = 'https://es.wikipedia.org' }
)

# botones.txt: una línea por botón, en el orden del panel:   Nombre | qué abre | web (opcional)
# las líneas que empiezan por # son comentarios
$ArchivoBotones = Join-Path $Raiz 'botones.txt'
function Copiar-Botones($lista) { return @($lista | ForEach-Object { @{ Nombre = [string]$_.Nombre; Abrir = [string]$_.Abrir; Web = [string]$_.Web } }) }
function Cargar-Botones {
    if (-not (Test-Path $ArchivoBotones)) { return (Copiar-Botones $BotonesDeSerie) }
    $lista = New-Object System.Collections.ArrayList
    foreach ($l in (Get-Content $ArchivoBotones -Encoding UTF8)) {
        if ($l -match '^\s*(#|$)') { continue }
        $p = @($l -split '\|' | ForEach-Object { $_.Trim() })
        if ($p.Count -lt 2 -or -not $p[0] -or -not $p[1]) { continue }
        [void]$lista.Add(@{ Nombre = $p[0]; Abrir = $p[1]; Web = $(if ($p.Count -ge 3) { $p[2] } else { '' }) })
    }
    if ($lista.Count -eq 0) { return (Copiar-Botones $BotonesDeSerie) }
    return @($lista)
}
function Guardar-Botones($lista) {
    $l = @(
        '# Botones del panel c00lgui, en orden. Una línea por botón:'
        '#   Nombre | qué abre (web, programa, archivo o carpeta) | web si el programa no está instalado (opcional)'
        '# Se puede cambiar desde el panel: Ajustes > Editar botones. Borra este archivo para volver a los de serie.'
        ''
    ) + @($lista | ForEach-Object { if ($_.Web) { "$($_.Nombre) | $($_.Abrir) | $($_.Web)" } else { "$($_.Nombre) | $($_.Abrir)" } })
    try { Set-Content -Path $ArchivoBotones -Value $l -Encoding UTF8; return $true } catch { return $false }
}
$Botones = Cargar-Botones

# ================= SKINS =================
# CÓMO AÑADIR UNA SKIN NUEVA
#   1. Copia el bloque de una skin parecida dentro de $Skins (más abajo) y cámbiale el nombre,
#      los colores, las frases y el 'Estilo' (una palabra corta y nueva, por ejemplo 'punk').
#      Las imágenes y sonidos van en una carpeta propia dentro de skins\.
#   2. Ponla en su grupo en $GruposSkins (justo después de $Skins) para que salga en el menú Skins.
#   3. Busca en el archivo un estilo parecido (por ejemplo 'punk') y añade el tuyo en los mismos sitios:
#      Fondo-Escena (fondo), Pintar-Burbuja (bocadillo), Pintar-Boton (botones), la lista de estilos
#      del Paint de la ventana y su switch (lo que se mueve), Lanzar (al abrir una app), Clic-Actor
#      (clic en el personaje), Efecto-Entrada (su intro), el temporizador de frases sueltas ($idleTimer),
#      el de animación ($ambTimer) y Abrir-Invitado / Pintar-Invitado (su ventanita en las discusiones).
#   4. Para que las demás opinen de ella, añade su nombre en 'AlVenirDe' y 'Opina' de cada skin,
#      y escribe discusiones nuevas en $Discusiones.
function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

# ---- datos de Enfosi (de sus wikis): los 7 Glaggles en el orden de sus oleadas ----
$EnfosiTipos = @('giggler', 'gazo', 'gloober', 'gembo', 'cheerer', 'gleeber', 'glaaber')
$EnfosiNombre = @{ giggler = 'Giggler'; gazo = 'Gazo'; gloober = 'Gloober'; gembo = 'Gembo'; cheerer = 'Cheerer'; gleeber = 'Gleeber'; glaaber = 'Glaaber'; gergro = 'Gergro'; borgack = 'Borgack'; risio = 'Risio' }
# velocidad al andar: los Gleebers son los más rápidos, los Cheerers corren mucho y los Glaabers son los más lentos
$EnfosiVel = @{ giggler = 1.6; gazo = 1.5; gloober = 1.25; gembo = 1.15; cheerer = 2.2; gleeber = 2.6; glaaber = 0.9 }
# clics que aguantan después de descubrirlos (según su vida en el juego)
$EnfosiVida = @{ giggler = 2; gazo = 2; gloober = 3; gembo = 3; cheerer = 2; gleeber = 3; glaaber = 5 }
# daño a la estatua de cada Enphosian (el del juego)
$EnfosiDanio = @{ giggler = 100; gazo = 40; gloober = 30; gembo = 100; cheerer = 500; gleeber = 150; glaaber = 200 }
# lo que dice el juego de cada uno (traducido)
$EnfosiTexto = @{
    giggler = '¡Un Giggler alegre! ¡Mira su sonrisa!'
    gazo    = '¡Un Gazo chiflado! ¡Un experto en tecnología y en disparar de lejos!'
    gloober = '¡Un Gloober tontorrón! ¡Ayuda a los que lo necesitan!'
    gembo   = '¡Un Gembo majo! ¡Un soldado con explosivos peligrosos!'
    cheerer = '¡Un Cheerer juguetón! ¿Qué habrá en esa caja de regalo?'
    gleeber = '¡Un Gleeber simpático! ¿Vamos a patinar?'
    glaaber = '¡Un Glaaber espeluznante! ¡Cuidado con su porra!'
}
# los cuatro fallos de un disfraz, en el orden de las imágenes de la wiki
$EnfosiFallo = @{ 1 = 'tenía la piel de otro color'; 2 = 'llevaba un símbolo falso en la camiseta'; 3 = 'no llevaba símbolo en la camiseta'; 4 = 'no tenía cara' }
# jefes tras las oleadas 2, 4 y 6: imagen, nombre, clics que aguanta, frase
$EnfosiJefes = @{
    2 = @('gergro', 'Gergro', 8, '¡JEFE: GERGRO! Un Giggler acróbata con pistola y bate. Dale clics hasta tumbarlo.')
    4 = @('borgack', 'Borgack', 10, '¡JEFE: BORGACK! Vuela con jetpack y tira dinamita. ¡Que no llegue a la estatua!')
    6 = @('risio', 'Risio', 12, '¡JEFE: RISIO! Usa las armas de la tienda contra ti. Es el último jefe.')
}
$EnfosiPoses = @{ gergro = 'skins\enfosi\gergro.png'; borgack = 'skins\enfosi\borgack.png'; risio = 'skins\enfosi\risio.png' }
foreach ($t in $EnfosiTipos) {
    $EnfosiPoses[$t] = "skins\enfosi\$t.png"; $EnfosiPoses["$($t)_e"] = "skins\enfosi\$($t)_enfosi.png"
    for ($i = 1; $i -le 4; $i++) { $EnfosiPoses["$t$i"] = "skins\enfosi\$($t)_falso$i.png" }
}

$Skins = [ordered]@{
    # ================================================================ c00lgui
    'c00lgui' = @{
        Estilo = 'hacker'; Titulo = 'c00lgui'; Sub = 'v6'; Alto = 312
        Fondo = (C 0 0 0); Borde = (C 255 0 0); Sombra = (C 90 0 0)
        TituloColor = (C 255 0 0); SubColor = (C 140 0 0)
        BtnFondo = (C 0 0 0); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 40 40); BtnBorde = (C 255 0 0); BtnBordeAncho = 1
        BtnHover = (C 45 0 0); BtnPress = (C 255 0 0); BarraBtnTexto = (C 255 0 0)
        StatusColor = (C 255 0 0); Fuente = 'Arial'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 2
        Hola = @(
            '> c00lgui v6 loaded. welcome back.'
            '> access granted. team c00lkidd join today!'
            '> injecting... done. hi.'
            '> SYSTEM COMPROMISED. c00lgui online.'
        )
        AlVenirDe = @{
            'SeaDrive'    = '> SeaDrive.exe terminated. c00lgui online.'
            'Static Miku' = '> TV signal hijacked. c00lgui online.'
            'Guillotina'  = '> survived the fat cat. c00lgui online.'
            'Angela'      = '> escaped the L Corp facility. c00lgui online.'
            'Mikaela'     = '> sniper left the server. c00lgui online.'
            'Zodiac'      = '> dodged six bullets. c00lgui online.'
            'Velvet'      = '> escaped the spider web. c00lgui online.'
            'Dune'        = '> the sand monster left. c00lgui online.'
            'Cordero y Cabra'      = '> cult.exe terminated. c00lgui online.'
            'Pyrophina y Zaratana' = '> kaiju.exe stomped the server. rebuilt. c00lgui online.'
            'Averi'                = '> sandwich.exe deleted. c00lgui online.'
            'Sebastian Solace'     = '> fish_merchant.exe closed. c00lgui online.'
            'Pursuer'              = '> predator.exe lost track of me. c00lgui online.'
            'Kasane Teto'          = '> birdbrain.exe closed. c00lgui online.'
            'Token'                = '> token.exe closed. finally, silence.'
            'Tetra'                = '> tetra went offline. status: do not disturb. relatable.'
            'Kevin'                = '> kevin.exe closed. pizza.dat still locked. 8 slices. encrypted.'
            'Kennyoung'            = '> kennyoung.exe closed. the guitar noise stopped. i kinda miss it.'
            'Enfosi'               = '> enfosi.exe closed. the statue is still standing. somehow.'
            'Gran'                 = '> gran.exe closed. me ofreció una vacuna. soy un programa. no tengo brazo.'
            'Nanachi'                = '> nanachi.exe went back to the abyss. stew.dat still corrupted.'
            'Evil Scary'             = '> evil_scary.exe left the server. admin panel still missing. i checked.'
            'Soft Fuzzy Man'       = '> soft_fuzzy_man.exe disconnected. tried to ping him. packet went right through.'
        }
        Yo = @('> c00lgui: still the best. no debate.', '> that one is me. obviously.')
        Opina = @{
            'SeaDrive'    = @('> SeaDrive? just a cat with a lanyard. easy target.', '> hacked SeaDrive''s wifi. password was "sarcasmo123"')
            'Static Miku' = @('> Static Miku keeps jamming my signal. respect.', '> tried to hack her TV. it hacked me back.')
            'Guillotina'  = @('> Guillotina ate my firewall. literally.', '> do NOT let the fat cat near the server room.')
            'Angela'      = @('> Angela is the only AI I can''t breach. yet.', '> L Corp security is... actually good. scary.')
            'Mikaela'     = @('> Mikaela''s aim looks like aimbot. it''s just skill. scary.', '> tried to hack her rifle. it''s not even a computer.')
            'Zodiac'      = @('> Zodiac shot my mouse cursor. twice.', '> cowboy.exe detected. threat level: chaotic.')
            'Velvet'      = @('> Velvet asked for my IP. said it was for "dinner".', '> do not trust the spider. her voice is a trap.exe')
            'Dune'        = @('> Dune tried to eat my keyboard. it was wireless.', '> dune.exe: 3 brain cells detected. all hungry.')
            'Cordero y Cabra'      = @('> the goat leaked the lamb''s password. respect.', '> tried to hack the cult. they started a ritual. logging off.')
            'Pyrophina y Zaratana' = @('> firewall vs actual fire: fire wins.', '> zaratana magnetized my hard drive. thanks a lot.')
            'Averi'                = @('> averi said my hacking was "cute". deleting myself.', '> she offered me a chicken sandwich. suspicious. ate it anyway.')
            'Sebastian Solace'     = @('> sebastian sold me a "firewall". it was a rock.', '> tried to hack his shop. he charged me for the attempt.')
            'Pursuer'              = @('> pursuer can''t see me. i''m behind 7 proxies.', '> he said "i see you". he did. logging off.')
            'Kasane Teto'          = @('> teto tried to download more ram. she downloaded a baguette.', '> she said "hiii" 47 times. i counted. i have logs.')
            'Token'                = @('> token turned my volume to 11. i can''t turn it down. send help.', '> token speaks in l33t. respect.')
            'Tetra'                = @('> tetra left me on read. 3 months. i have logs.', '> tetra''s cap says "failure". mine says "c00lkidd". we are not the same.')
            'Kevin'                = @('> tried to hack kevin''s pizza. he bit my keyboard. 0/10.', '> kevin draws in ms paint. respect the oldschool.')
            'Kennyoung'            = @('> hacked kennyoung''s channel. uploaded 10h of glitch. more views than his songs. sorry kenny.', '> kenny plays 4 chords. i hack with 4 keys. same energy.')
            'Enfosi'               = @('> enfosi: spot the fake glaggle. i am the fake glaggle.', '> i hacked the statue. it now says "team c00lkidd".')
            'Gran'                 = @('> intenté hackear antihuman inc. el firewall tiene colmillos.', '> gran quiere convertir a todos en furries. a mí no puede. soy código. ez.')
            'Nanachi'                = @('> tried to hack nanachi. found only fur. 100% fluffy. 0% data.', '> nanachi''s stew crashed my antivirus. respect.')
            'Evil Scary'             = @('> tried to ban evil scary. it said "IT IS EVIL AND SCARY". ban failed.', '> evil scary is the only thing c00lkidd is afraid of. don''t tell him.')
            'Soft Fuzzy Man'       = @('> soft fuzzy man has no hitbox. no hitbox = no hack. respect.', '> he flirted with my firewall. it let him in.')
        }
        Frases = @(
            '> payload delivered.'
            '> firewall bypassed. too easy.'
            '> team c00lkidd join today!'
            '> exploit executed. no one saw that.'
            '> process hijacked successfully.'
        )
        Idle = @(
            '> c00lkidd is watching...'
            '> team c00lkidd join today!'
            '> scanning network... 0 threats (we are the threat)'
            '> admin privileges: GRANTED'
            '> server shutdown in 3... 2... jk'
            '> uploading decal to every brick...'
            '> antivirus status: crying'
            '> you have been hacked by c00lkidd'
            '> pinging 127.0.0.1... home sweet home'
            '> rewriting reality.exe ...'
            '> 1337 h4x0r m0d3: ON'
            '> nobody can stop the c00lgui'
        )
        Clic = @()
        PorApp = @{
            'YouTube'       = @('> hijacking youtube.com ...', '> streaming payload via youtube.com')
            'Word'          = @('> injecting into WINWORD.EXE ...', '> rewriting your essay. jk.')
            'Excel'         = @('> cracking spreadsheet encryption ...', '> =HACK(A1:Z999) ok')
            'PowerPoint'    = @('> injecting slide 1: "c00lkidd was here"', '> POWERPNT.EXE pwned')
            'Outlook'       = @('> reading your inbox... boring.', '> sending "join today" to all contacts. jk')
            'OneNote'       = @('> decrypting secret notes ...')
            'Access'        = @('> SQL injection: DROP TABLE homework;')
            'Publisher'     = @('> publishing c00lkidd propaganda ...')
            'Teams'         = @('> joining meeting as c00lkidd ...')
            'OneDrive'      = @('> downloading the cloud ...')
            'Office Web'    = @('> breaching office.com mainframe ...')
            'Bloc de notas' = @('> notepad.exe: the hacker IDE')
            'Calculadora'   = @('> calculating 1337 ...', '> 2+2 = c00lkidd')
            'Explorador'    = @('> browsing C:\ like I own it')
            'CMD'           = @('> real hacker mode activated', '> type "tree" to look cool')
        }
    }
    # ================================================================ SeaDrive (página web)
    'SeaDrive' = @{
        Estilo = 'web'; Titulo = 'SeaDrive'; Sub = 'virtual assistant  ·  HowTo'; Alto = 344; Top = 32
        Url = 'https://www.seadrive.howto/asistente'
        Fondo = (C 236 247 255); Borde = (C 40 130 200); Barra1 = (C 110 200 245); Barra2 = (C 40 130 200)
        TituloColor = (C 255 255 255); SubColor = (C 255 210 40)
        BtnFondo = (C 255 198 26); BtnTexto = (C 20 20 20); BtnTextoHover = (C 20 20 20); BtnBorde = (C 20 20 20); BtnBordeAncho = 1
        BtnHover = (C 140 220 60); BtnPress = (C 40 130 200); BarraBtnTexto = (C 20 20 20)
        StatusColor = (C 30 30 30); Fuente = 'Segoe UI'; FuenteTitulo = 'Segoe UI Black'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\seadrive\seadrive.gif'
        Pb = @(410, 98, 190, 150); PbFondo = (C 255 255 255); PbBorde = $true
        Burbuja = @(410, 254, 190, 70); BurFondo = (C 255 255 255); BurTexto = (C 20 20 20); BurFuente = 'Segoe UI'
        Hola = @(
            'Hola, soy SeaDrive. ¿Qué quieres ahora?'
            'Ah, eres tú. Hola. Supongo.'
            'SeaDrive en línea. Con desgana, pero en línea.'
            'Bienvenido de nuevo. Te he echado de menos. (mentira)'
            'Página cargada. Tardó lo suyo, como tú por las mañanas.'
        )
        AlVenirDe = @{
            'c00lgui'     = '¿Ya te cansaste del hacker ese? Bien. Aquí mando yo.'
            'Static Miku' = 'Uf, cuánto color. Tranquilo, aquí todo es aburrido.'
            'Guillotina'  = 'Se fue la gata gorda. Por fin. Oía su estómago desde aquí.'
            'Angela'      = 'Bienvenido a una empresa normal. Sin monstruos. Bueno, estoy yo.'
            'Mikaela'     = 'La francotiradora se ha ido. Ya puedo asomar la cabeza.'
            'Zodiac'      = 'Por fin. Ese vaquero disparaba a todo lo que se movía. Incluido yo.'
            'Velvet'      = 'La araña se ha ido. Revisa que no haya dejado telarañas en tus carpetas.'
            'Dune'        = 'Se fue el bicho de arena. Lo ha dejado todo mojado.'
            'Cordero y Cabra'      = 'Se ha ido el culto. Me han dejado tres folletos y una cabra gritando en el buzón.'
            'Pyrophina y Zaratana' = 'Por fin. Mi escritorio era zona catastrófica. Literalmente.'
            'Averi'                = 'Averi se ha ido. Ha dejado migas de sándwich en el teclado. Muchas.'
            'Sebastian Solace'     = 'Se fue el pez de la tienda. Me intentó vender pilas para mis auriculares.'
            'Pursuer'              = 'Se fue el del bosque. Ya puedo dejar de mirar detrás de mí.'
            'Kasane Teto'          = 'Se fue la de las coletas. Por fin silencio. Me cantaba en los auriculares.'
            'Token'                = 'Se fue el gato ruidoso. Me zumban los oídos. Gracias por nada.'
            'Tetra'                = 'Se fue Tetra. Somos del mismo creador. Ni nos despedimos. Muy nuestro.'
            'Kevin'                = 'Se fue Kevin. Por fin dejo de oír la canción de la pizza. ...la sigo oyendo en mi cabeza.'
            'Kennyoung'            = 'Se fue Kenny. El amigo de YonKaGor. Muy majo. Muy ruidoso. Muy majo.'
            'Enfosi'               = 'Se acabaron las oleadas. Tantas sonrisas me cansaban.'
            'Gran'                 = 'Se ha ido el dragón de la jeringuilla. Por fin puedo dormir sin firmar nada.'
            'Nanachi'                = 'Se fue Nanachi. Nos hemos pasado la tarde sin hablar. Ha sido perfecto.'
            'Evil Scary'             = 'Se ha ido Evil Scary. Por fin dejo de oír ese botecito. Lo sigo oyendo en sueños.'
            'Soft Fuzzy Man'       = 'Se fue Soft Fuzzy Man. Me ha dejado la pantalla llena de niebla rosa. Muy bonito. Muy molesto.'
        }
        Yo = @('Esa skin soy yo. La mejor, obviamente.', 'Ah, sí. Yo. Elección correcta por una vez.')
        Opina = @{
            'c00lgui'     = @('c00lkidd se cree hacker. Seguro que su contraseña es 1234.', 'El panel rojo ese... muy 2006.')
            'Static Miku' = @('Miku es demasiado alegre. Me cansa solo mirarla.', 'Miku está bien. Si te gusta el ruido.')
            'Guillotina'  = @('Guillotina también es una gata. No somos iguales. Yo no me como a la gente.', 'Esa gata se comió mi cable de red. No es broma.')
            'Angela'      = @('Angela es otra asistente IA. Competencia. No me cae bien.', 'Angela te llama "Manager". Yo te llamo "eh, tú".')
            'Mikaela'     = @('Mikaela es otra gata. Con rifle. Esto ya parece una invasión felina.', 'Mikaela dice "GG EZ" a todo. Hasta a abrir el Excel.')
            'Zodiac'      = @('Zodiac le disparó a mi Wi-Fi. Literalmente.', 'Un gato vaquero loco. Lo que me faltaba.')
            'Velvet'      = @('Velvet me llamó "cielo". Luego "aperitivo". Mala combinación.', 'Esa voz tan dulce no me engaña. Es una araña.')
            'Dune'        = @('Dune me preguntó si los asistentes saben a pollo. No.', 'Dune tiene tres palabras de vocabulario. Las tres son comida.')
            'Cordero y Cabra'      = @('Un cordero que no habla y una cabra que no se calla. Equilibrio.', 'Me invitaron a su culto. Pregunté el horario. Dijeron "eterno".')
            'Pyrophina y Zaratana' = @('Dos monstruos gigantes peleando. Como mi día a día, pero más ruidoso.', 'Zaratana se comió mi router. Y eructó. Gracias.')
            'Averi'                = @('Averi me dijo que tengo "cara de cansada". Tiene razón. Me molesta.', 'Es demasiado alegre. Pero si alguien se mete con ella, me enfado. Un poco.')
            'Sebastian Solace'     = @('Sebastian dice que es "mi único amigo". Qué triste para los dos.', 'Le compré algo a Sebastian. No funciona. No hay devoluciones.')
            'Pursuer'              = @('Pursuer me dijo "te veo". Yo también te veo, y no me impresiona.', 'Ese no come nada que no esté fresco. Por eso no me come a mí: estoy agotada.')
            'Kasane Teto'          = @('Teto baila en el metro sin que nadie la mire. La envidio un poco. Solo un poco.', 'Teto me dijo "hiii". Le dije "byeee". No lo pilló.')
            'Token'                = @('Token pone la música tan alta que la oigo con los auriculares puestos. Increíble. Para mal.', 'Token me pidió que subiera el volumen. Me fui a otra habitación.')
            'Tetra'                = @('Tetra es lo más parecido a un primo que tengo. Un primo que tampoco contesta.', 'Tetra y yo podríamos estar juntos en silencio horas. Lo mejor de lo mejor.')
            'Kevin'                = @('Kevin grita por una pizza. Yo no grito ni por mi vida. Somos muy distintos.', 'Toqué la pizza de Kevin sin querer. Ahora vivo con miedo.')
            'Kennyoung'            = @('Kenny es amigo de YonKaGor. Así que es medio familia. La familia ruidosa.', 'Kenny toca la guitarra a todas horas. Me pongo los auriculares. Los suyos, porque los míos no aguantan.')
            'Enfosi'               = @('Enfosi va de distinguir sonrisas falsas. Yo no sonrío. Problema resuelto.', 'Siete oleadas de Glaggles. Yo con una oleada de correos ya tengo bastante.')
            'Gran'                 = @('Gran me miró las orejas y dijo "medio camino hecho". No pienso preguntar.', 'Me ofreció un contrato de cuarenta páginas. Lo firmé sin leerlo. Era para que me dejara en paz. ...¿verdad?')
            'Nanachi'                = @('Nanachi es de las pocas que no me hace hablar. La aprecio. Bueno, le aprecio. Lo que sea.', 'Me hizo una infusión y dormí dos días. Lo mejor que me ha pasado.')
            'Evil Scary'             = @('Evil Scary no tiene ojos y aun así me mira. Odio eso. Lo odio mucho.', 'Le puse un pop-up de "cerrar". Lo atravesó. Pues vale.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man me pidió café. Le di una taza. La atravesó. Qué desperdicio.', 'Es como un salvapantallas con sentimientos.')
        }
        Frases = @(
            'Ya está. No me des las gracias, no me pagan.'
            'Otra ventana más. Tu RAM te odia.'
            'Procesando con el mínimo entusiasmo posible...'
            'Listo. Ahora haz como que trabajas.'
            'Si algo falla, no fue culpa mía.'
            'Wow. Increíble elección. De verdad. (no)'
        )
        Idle = @(
            'Sigo aquí. No es que tenga opción.'
            'Consejo del día: parpadea. Llevas un rato sin hacerlo.'
            '¿Has bebido agua hoy? No me mientas.'
            'Top 10 cosas que hacer hoy: 1. Cerrar pestañas.'
            'Mi conexión Wi-Fi está mejor que tu ánimo hoy.'
            'Estoy desfragmentando mis sentimientos.'
            'Los gatos asistentes también necesitamos vacaciones.'
            'Actualizando... era broma, no hago nada.'
            'Ponte recto. Sí, tú.'
            'Consejo nº2: levántate y estira. Yo no puedo, vivo aquí.'
            'He leído todo internet. No lo recomiendo.'
            'Si me necesitas, estaré aquí. Literalmente siempre.'
            '¿Sabías que mi nombre viene de "C: Drive"? Pues eso.'
            'Información útil: ninguna. De nada.'
            'Mis auriculares no son decoración, que lo sepas.'
            'Buscando motivación... 0 resultados.'
            'Esta página no usa cookies. Me las comí.'
            'Error 404: ganas de trabajar no encontradas.'
        )
        Clic = @(
            'Oye, no me toques.'
            'Miau. ¿Contento?'
            'Eso es acoso al asistente.'
            'Clic detectado. Ego herido.'
            'Sí, soy adorable. Ya lo sé.'
            'Haz clic en los botones, no en mí.'
            'Cada clic me cuesta un poco de batería emocional.'
            'Vale, vale. Te saludo. Hola. Ya.'
        )
        PorApp = @{
            'YouTube'       = @('¿YouTube? "Solo un vídeo", dijiste. Ya.', 'Te pongo un temporizador mental: 3 horas.', 'Mira algo útil. O un vídeo de gatos, también vale.')
            'Word'          = @('Word abierto. La página en blanco te mira. Suerte.', 'Recuerda guardar. Nadie lo recuerda nunca.', 'Times New Roman, 12. Como en 2003.')
            'Excel'         = @('Celdas. Muchas celdas. Que lo disfrutes.', 'Si sale #¡REF!, finge que no lo viste.', 'Excel: donde los sueños se convierten en fórmulas.')
            'PowerPoint'    = @('Otra presentación con transiciones de estrellas, ¿no?', 'Comic Sans no. Por favor.', 'Diapositiva 1 de 47. Ánimo.')
            'Outlook'       = @('Bandeja de entrada: 999+. No mires.', '"Responder a todos" es un arma. Cuidado.', 'Correos que podrían haber sido nada.')
            'OneNote'       = @('Notas que jamás volverás a leer. Precioso.', 'Apunta esto: SeaDrive es el mejor asistente.')
            'Access'        = @('¿Access? ¿En serio? Vale, valiente.', 'Bases de datos. Qué emocionante. (bostezo)')
            'Publisher'     = @('Publisher... no sabía que seguía vivo.', 'Vas a hacer un cartel de "se busca gato", ¿verdad?')
            'Teams'         = @('Pon cara de estar atento en la reunión.', 'Te has dejado el micro abierto. Es broma. ¿O no?')
            'OneDrive'      = @('Tus archivos en la nube. Mi casa, básicamente.', 'Sincronizando... tus excusas.')
            'Office Web'    = @('Office en el navegador. Mi hábitat natural.', 'Pestaña nueva. Otra más. Ya van muchas.')
            'Bloc de notas' = @('Bloc de notas: minimalismo puro.', 'Sin formato, sin dramas. Me gusta.')
            'Calculadora'   = @('2 + 2 son 4. Para eso no hacía falta abrirla.', 'Calculando cuánto tiempo has perdido hoy...')
            'Explorador'    = @('Buscando "final_final_v3_DEFINITIVO.docx"...', 'Tu escritorio necesita una limpieza. Solo digo.')
            'CMD'           = @('Ooh, modo hacker. Qué miedo.', 'No escribas nada raro ahí, que te veo.', '¿Tú también quieres ser c00lkidd? Qué original.')
        }
    }
    # ================================================================ Static Miku (tele de dibujos)
    'Static Miku' = @{
        Estilo = 'tele'; Titulo = 'STATIC'; Sub = 'miku  ·  flavor foley'; Alto = 312
        Fondo = (C 232 38 28); Borde = (C 0 0 0); Sombra = (C 0 0 0)
        TituloColor = (C 255 225 50); SubColor = (C 90 225 245)
        Paleta = @((C 90 220 245), (C 255 225 50), (C 255 105 205), (C 120 235 95), (C 255 165 45))
        BtnFondo = (C 90 220 245); BtnTexto = (C 0 0 0); BtnTextoHover = (C 0 0 0); BtnBorde = (C 0 0 0); BtnBordeAncho = 3
        BtnHover = (C 255 255 255); BtnPress = (C 60 45 190); BarraBtnTexto = (C 0 0 0)
        StatusColor = (C 255 255 255); Fuente = 'Comic Sans MS'; FuenteTitulo = 'Comic Sans MS'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\staticmiku\miku.gif'; GifClic = 'skins\staticmiku\miku_feliz.gif'; GifRaro = 'skins\staticmiku\miku_ojos.gif'
        Pb = @(414, 76, 182, 132); PbFondo = (C 0 0 0); PbBorde = $false
        Burbuja = @(404, 240, 202, 56); BurFondo = (C 255 255 255); BurTexto = (C 20 20 20); BurFuente = 'Comic Sans MS'
        Hola = @(
            '¡Bzzzt! ¡Hola, hola! Estás viendo el canal Static.'
            '¡Ya estoy aquí! ¿Qué ponemos hoy en la tele?'
            '¡Sintonizando... sintonizado! ¡Hola!'
            '¡Señal recuperada! ¡Empieza el programa!'
        )
        AlVenirDe = @{
            'c00lgui'    = '¡Bzzzt! ¡Ese hacker daba miedo! ¡Hola!'
            'SeaDrive'   = '¡Hola! SeaDrive es un poco gruñón, ¿verdad? ¡Jiji!'
            'Guillotina' = '¡Uf! ¡Casi me come la gatita gigante! ¡Hola!'
            'Angela'     = '¡Bzzt! ¡Qué sitio tan gris era ese! ¡Aquí todo tiene color!'
            'Mikaela'    = '¡Bzzt! ¡Ya no hay francotiradores! ¡A bailar!'
            'Zodiac'     = '¡Uf! ¡Ya me puedo mover otra vez! ¡Hola!'
            'Velvet'     = '¡Bzzt! ¡Ya no hay arañas! ¡Qué alivio!'
            'Dune'       = '¡Hola! ¡Dune ha dejado la tele llena de agua! ¡Bzzzt!'
            'Cordero y Cabra'      = '¡Bzzt! ¡Ya no hay rituales en mi tele! ¡Hola!'
            'Pyrophina y Zaratana' = '¡Uf! ¡Ya no tiembla la antena! ¡Hola!'
            'Averi'                = '¡Hola! ¡Averi me ha dejado un sándwich! ¡Y un dibujo!'
            'Sebastian Solace'     = '¡Bzzt! ¡Se cerró la tienda del pez! ¡Hola!'
            'Pursuer'              = '¡Uf! ¡Ya no hay nadie en el bosque! ¡Hola!'
            'Kasane Teto'          = '¡Bzzt! ¡Se fue Teto! ¡Me debe un dúo! ¡Hola!'
            'Token'                = '¡Bzzt! ¡Token se ha ido! ¡Mis altavoces vuelven a funcionar! ¡Hola!'
            'Tetra'                = '¡Bzzt! ¡Tetra se ha ido! ¡Me dejó en visto! ¡Otra vez!'
            'Kevin'                = '¡Bzzt! ¡Kevin se ha ido! ¡Me dejó la canción de la pizza pegada en la antena!'
            'Kennyoung'            = '¡Bzzt! ¡Kenny se ha ido! ¡Me prometió un feat pop-punk!'
            'Enfosi'               = '¡Bzzt! ¡Se han ido los Glaggles! ¡Sonreían tanto como yo!'
            'Gran'                 = '¡Bzzt! ¡Se ha ido el señor de la bata! ¡Me quería poner una vacuna en la antena!'
            'Nanachi'                = '¡Bzzt! ¡Nanachi se ha ido! ¡Tiene un pelo tan mullido que se me ha erizado la antena!'
            'Evil Scary'             = '¡Bzzt! ¡Evil Scary se ha ido! ¡Mi tele vuelve a enseñar dibujos y no sonrisas rojas!'
            'Soft Fuzzy Man'       = '¡Bzzt! ¡Se ha ido Soft Fuzzy Man! ¡Mi tele echa de menos su estática!'
        }
        Yo = @('¡Esa soy yo! ¡Hola, yo!', '¡Elígeme! ¡Elígeme! ¡Bzzt!')
        Opina = @{
            'c00lgui'    = @('¡El hacker rojo me da un poco de miedo! ¡Bzzt!', '¡c00lkidd intentó piratear mi tele! ¡Solo encontró dibujos!')
            'SeaDrive'   = @('¡SeaDrive es mi amigo! Aunque nunca sonríe...', '¡Me encantan los auriculares de SeaDrive!')
            'Guillotina' = @('¡Guillotina es una gatita enorme! ¡Quiero abrazarla! ...¿o mejor no?', '¡No dejes que Guillotina se coma la antena!')
            'Angela'     = @('Angela es muy seria... ¡como una presentadora de noticias!', '¡Angela trabaja en un sitio con monstruos! ¡Como en los dibujos!')
            'Mikaela'    = @('¡Mikaela tiene unas gafas verdes chulísimas!', '¡Mikaela dice que mi tele delata su posición! ¡Jiji!')
            'Zodiac'     = @('¡El vaquero me da miedo! ¡No me muevo, no me muevo!', '¡Zodiac le disparó a mi antena! ¡Bzzzt!')
            'Velvet'     = @('¡Velvet tiene una voz muy bonita! ...pero me da escalofríos.', '¡Ocho patas! ¡Podría bailar el doble que yo!')
            'Dune'       = @('¡Dune es como un pececito! ¡Un pececito con muchos dientes!', '¡Dune quiso comerse mi lazo!')
            'Cordero y Cabra'      = @('¡El Cordero es súper mono! La Cabra grita mucho... ¡como yo!', '¡Quieren que cante en sus rituales! ¿Habrá purpurina?')
            'Pyrophina y Zaratana' = @('¡Pelea de monstruos! ¡Como los dibujos del sábado!', '¡Zaratana atrajo mi tele con su imán! ¡Bzzzt!')
            'Averi'                = @('¡Averi es una zorrita adorable! ¡Somos mejores amigas!', '¡Averi dijo que mi tele es vieja! Bueno, clásica. ¡Me vale!')
            'Sebastian Solace'     = @('¡Sebastian tiene una cola larguísima! ¡Como una serpentina!', '¡Le pedí un descuento a Sebastian! ¡Me dio un "no" muy largo!')
            'Pursuer'              = @('¡Pursuer da mucho miedo! ¡Apago la tele cuando pasa!', '¡Pursuer toca la armónica! ¡Quiero hacer un dúo!')
            'Kasane Teto'          = @('¡Teto y yo somos amigas desde siempre! ¡Bueno, desde el uno de abril!', '¡Teto dice que tiene 31 años! ¡Yo tengo 16 para siempre! ¡Ja!')
            'Token'                = @('¡Token me hizo un remix! ¡Bzzzzt! ¡Me rompió la tele de la emoción!', '¡Token grita más que yo! ¡Eso no lo había conseguido nadie!')
            'Tetra'                = @('¡Tetra baila disco! ¡Yo bailo con estática! ¡Fiesta!', '¡Tetra dice que soy pop puro! ¡Bzzt! ¡Me lo apunto!')
            'Kevin'                = @('¡Kevin tiene una canción! ¡Bzzt! ¡Quiero hacer un dueto con él!', '¡Kevin es verde como mi pelo! ...bueno, el mío es turquesa. ¡Casi!')
            'Kennyoung'            = @('¡Kenny toca la guitarra muy rápido! ¡Bzzt! ¡Mi antena baila sola!', '¡Le pedí a Kenny una canción para mi tele! ¡Dice que la hace mañana! Lleva diciendo eso tres semanas.')
            'Enfosi'               = @('¡Los Glaggles sonríen siempre! ¡Somos familia! ¡Bzzt!', '¡Le pegué a un Gazo sin querer! ¡Era inocente! ¡Lo siento, Gazo!')
            'Gran'                 = @('¡Gran nunca sonríe! ¡Le hice dibujos y los guardó en una carpeta que pone "MUESTRAS"!', '¡Bzzt! ¡Dice que soy una tele y que no le sirvo! ¡Qué grosero!')
            'Nanachi'                = @('¡Nanachi es como un peluche que habla! ¡Bzzt! ¡Y dice cosas muy sabias!', '¡Probé su estofado! ¡Mi tele se puso en blanco y negro del susto!')
            'Evil Scary'             = @('¡Evil Scary sale en mi tele cuando está apagada! ¡Bzzt! ¡No me gusta nada!', '¡Le canté una canción para que se calmara! ¡Botó más rápido!')
            'Soft Fuzzy Man'       = @('¡Soft Fuzzy Man es borroso como yo! ¡Bzzt! ¡Somos familia!', '¡Cantamos su canción a dúo! ¡Él hacía los coros de niebla!')
        }
        Frases = @(
            '¡Listo! ¡Como en los dibujos de los sábados!'
            '¡Ta-chán! ¡Abierto!'
            '¡Bzzt! ¡Señal recibida!'
            '¡Así es como debería ser!'
            '¡Yay! ¡Allá vamos!'
        )
        Idle = @(
            '¿Te acuerdas de cuando veías dibujos en pijama?'
            'Un poco de nostalgia está bien... ¡pero no demasiada!'
            'No toques la antena, que se va la señal.'
            '¡Bzzzzzt! ...perdón, interferencias.'
            '¡La la la~! ♪'
            'Los anuncios vuelven en 3... 2... ¡es broma!'
            '¿Sabías que el ruido de la tele se llama estática? ¡Como yo!'
            'Hoy es un buen día para un maratón de dibujos.'
            'Si me ves en blanco y negro, dale un golpecito a la tele.'
            '¡Mis coletas captan el wifi del vecino!'
            'Canal 3... canal 4... ¡nada mejor que esto!'
            'Tengo el lazo amarillo más bonito de la tele.'
            '¡No te vayas! ¡Después de la pausa viene lo mejor!'
            '¿Bailamos? ¡Un, dos, tres! ♪'
            'Ponte cómodo, que el programa dura para siempre.'
        )
        Clic = @(
            '¡Jiji! ¡Hola!'
            '¡Yay! ¡Me has encontrado!'
            '¡Eso hace cosquillas!'
            '¡Bzzt! ¡Toque recibido!'
            '¡Otra vez, otra vez!'
            '¡Saluda a la cámara! ¡Estás en la tele!'
        )
        Raro = @(
            '...¿sigues ahí?'
            '...no cambies de canal.'
            '...te estoy viendo a través de la pantalla.'
            '...la señal nunca se acaba.'
        )
        PorApp = @{
            'YouTube'       = @('¡YouTube! ¡Busquemos dibujos antiguos!', '¡Un vídeo más y a dormir! ...¿vale?')
            'Word'          = @('¡Escribamos un cuento de dibujos animados!', '¡Érase una vez... una hoja en blanco!')
            'Excel'         = @('¡Cuadraditos! ¡Como una tele pixelada!', '¡Uy, cuántos números! ¡Bzzt!')
            'PowerPoint'    = @('¡Diapositivas! ¡Como una película muy lenta!', '¡Ponle muchos colores, como yo!')
            'Outlook'       = @('¡Tienes correo! ...o eso espero.', '¡Cartas por la tele! ¡Qué moderno!')
            'OneNote'       = @('¡Apunta tus ideas antes de que se las lleve la estática!')
            'Access'        = @('Mmm... esto parece serio. ¡Suerte!')
            'Publisher'     = @('¡Hagamos un póster de mi programa!')
            'Teams'         = @('¡Saluda a la cámara! ¡Estás en la tele!', '¡Una reunión! ¿Hay galletas?')
            'OneDrive'      = @('¡Tus cosas en las nubes! Como en los dibujos.')
            'Office Web'    = @('¡Navegando por los canales de internet!')
            'Bloc de notas' = @('Una hoja en blanco... ¡como una tele sin señal!')
            'Calculadora'   = @('¡1, 2, 3! ¡Sé contar!', '¡Uno más uno... son dos dibujos!')
            'Explorador'    = @('¡A explorar! ¡Como en una aventura!')
            'CMD'           = @('¡Uy, pantalla negra! ¿Se ha ido la señal?', '¡Eso parece la tele apagada!')
        }
    }
    # ================================================================ Guillotina (Mewgenics)
    'Guillotina' = @{
        Estilo = 'mew'; Titulo = 'GUILLOTINA'; Sub = 'house boss  ·  mewgenics'; Alto = 312
        Fondo = (C 46 33 40); Borde = (C 20 14 16)
        TituloColor = (C 240 228 200); SubColor = (C 215 75 60)
        BtnFondo = (C 245 236 212); BtnTexto = (C 25 20 22); BtnTextoHover = (C 25 20 22); BtnBorde = (C 25 20 22); BtnBordeAncho = 2
        BtnHover = (C 215 80 65); BtnPress = (C 120 25 25); BarraBtnTexto = (C 25 20 22)
        StatusColor = (C 240 228 200); Fuente = 'EdmundMcMillen_INTLv4'; FuenteTitulo = 'EdmundMcMillen_INTLv4'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\guillotina\g_idle.gif'
        FondoImg = 'skins\guillotina\callejon.jpg'
        # intro (imágenes del juego): las fotos que pasan rápido, el callejón de la jefa, ella, el cartel y el marco de cables
        IntroFotos = @('skins\guillotina\intro_callejon1.jpg', 'skins\guillotina\intro_callejon2.jpg', 'skins\guillotina\intro_callejon3.jpg', 'skins\guillotina\cementerio.jpg', 'skins\guillotina\callejon.jpg')
        IntroJefa = 'skins\guillotina\intro_jefa.jpg'; IntroGuillotina = 'skins\guillotina\intro_guillotina.png'
        IntroCartel = 'skins\guillotina\intro_cartel.png'; IntroMarco = 'skins\guillotina\intro_marco.png'
        Actores = @(
            @{ Id = 'G'; Gif = 'skins\guillotina\g_idle.gif'; Rect = @(432, 66, 316, 190)
               Extra = @{ furiosa = 'skins\guillotina\g_furiosa.gif'; clic = 'skins\guillotina\g_enfado.gif'; inhala = 'skins\guillotina\g_inhala.gif'; inhalaf = 'skins\guillotina\g_inhala_f.gif'
                          lanza = 'skins\guillotina\g_lanza.gif'; barriga = 'skins\guillotina\g_barriga.gif'; digiere = 'skins\guillotina\g_digiere.gif'; herida = 'skins\guillotina\g_herida.gif' } }
        )
        Cartel = 'skins\guillotina\cartel_g.png'
        Sonidos = @{
            intro = @('skins\guillotina\s_enfado_sfx.wav'); furia = @('skins\guillotina\s_enfado.wav'); radio = @('skins\guillotina\radio_intro.wav')
            golpe = @('skins\guillotina\s_golpe1.wav', 'skins\guillotina\s_golpe2.wav', 'skins\guillotina\s_golpe3.wav'); golpef = @('skins\guillotina\s_golpef1.wav', 'skins\guillotina\s_golpef2.wav')
            comer = @('skins\guillotina\s_inhala1.wav', 'skins\guillotina\s_inhala2.wav'); digiere = @('skins\guillotina\s_digiere.wav'); lanza = @('skins\guillotina\s_lanza.wav')
            barriga = @('skins\guillotina\s_barriga.wav'); muere = @('skins\guillotina\s_muere.wav'); mordisco = @('skins\guillotina\s_mordisco.wav'); paso = @('skins\guillotina\s_paso.wav')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 250 244 228); BurTexto = (C 30 20 22); BurFuente = 'TikaFont Adjusted'
        Hola = @(
            '*Guillotina se sienta encima de tu barra de tareas.*'
            'WMEW 99.9: ¡Atención! Un enorme gato se dirige a tu escritorio.'
            '*Ruge. Tiene hambre.*'
            '*Te mira fijamente. Se relame.*'
        )
        AlVenirDe = @{
            'c00lgui'     = '*Guillotina se come los restos del panel rojo. Sabe a código.*'
            'SeaDrive'    = '*Huele a otro gato. Gruñe muy fuerte.*'
            'Static Miku' = '*Se ha tragado la antena de la tele. No se arrepiente.*'
            'Angela'      = 'WMEW 99.9: Un gato gigante ha escapado de una instalación de L Corp...'
            'Mikaela'     = '*Escupe una bala de francotirador.*'
            'Zodiac'      = '*Tiene seis balas en la barriga. No le importa.*'
            'Velvet'      = '*Se come una telaraña. Sabe a araña.*'
            'Dune'        = '*Huele a pescado. Guillotina se relame.*'
            'Cordero y Cabra'      = '*Se ha comido la ofrenda del culto. Y el altar.*'
            'Pyrophina y Zaratana' = 'WMEW 99.9: Los kaijus se van. Guillotina vuelve a ser lo más grande del barrio.'
            'Averi'                = '*Se ha comido el sándwich de pollo de Averi. Sigue con hambre.*'
            'Sebastian Solace'     = '*Se ha comido la mitad de la tienda de Sebastian. Sin pagar.*'
            'Pursuer'              = '*Huele el bosque. Pursuer se ha ido. Le ha dejado la carne vieja.*'
            'Kasane Teto'          = '*Huele a pan. Teto se ha ido. Se ha dejado media baguette. Ya no.*'
            'Token'                = '*Escupe una ficha de recreativa. Era Token. Sigue sonando.*'
            'Tetra'                = '*Huele a fideos instantáneos. Tetra se ha ido. Los fideos no.*'
            'Kevin'                = '*Huele a pizza. Kevin se ha ido. La pizza no. Se relame.*'
            'Kennyoung'            = '*Escupe una púa de guitarra. Kenny se ha ido.*'
            'Enfosi'               = '*Se ha ido el juego de las caritas. A Guillotina le sabían a gominola.*'
            'Gran'                 = '*Se ha ido el dragón verde. Guillotina se ha comido su jeringuilla. Ahora tiene orejas nuevas. Ya tenía.*'
            'Nanachi'                = '*Huele a estofado. Nanachi se ha ido. La olla no. Se la come.*'
            'Evil Scary'             = '*Guillotina se relaja. La bola negra se ha ido. No se la ha podido comer.*'
            'Soft Fuzzy Man'       = '*Guillotina se relame. La nube rosa se ha ido. Sabía a algodón de azúcar. No llenaba nada.*'
        }
        Yo = @('*Se mira a sí misma. Le gusta lo que ve.*', '*Ronronea. Sí, esa es ella.*')
        Opina = @{
            'c00lgui'     = @('*Mira el panel rojo. Parece un filete. Se relame.*', '*Intentó comerse a c00lkidd. Sabía a bits.*')
            'SeaDrive'    = @('*Huele a otro gato en el sistema. Gruñe.*', '*SeaDrive le parece un aperitivo con auriculares.*')
            'Static Miku' = @('*Mira las coletas de Miku como si fueran fideos.*', '*La tele de Miku le parece una caja de comida.*')
            'Angela'      = @('*Angela no parece comestible. Lo va a intentar igual.*', 'WMEW 99.9: Fuentes de L Corp la clasifican como anomalía de riesgo WAW.')
            'Mikaela'     = @('*Mikaela le apunta. Guillotina abre la boca. Se comerá la bala.*', '*Huele a otra gata. Y a pólvora.*')
            'Zodiac'      = @('*Zodiac es del mismo mundo. Guillotina lo respeta. Un poco.*', '*Una vez se comió el sombrero de Zodiac.*')
            'Velvet'      = @('*Velvet la llama "aperitivo". Guillotina se ríe. Ella es el plato principal.*', '*Mira las patas de Velvet. Ocho patas. Ocho bocados.*')
            'Dune'        = @('*Dune y Guillotina se miran. Los dos tienen hambre. Tensión.*', '*Guillotina piensa que Dune sería buen sushi.*')
            'Cordero y Cabra'      = @('*Mira al Cordero. Huele a cordero asado. Se relame.*', '*La Cabra le grita. Guillotina ruge más fuerte.*')
            'Pyrophina y Zaratana' = @('*Guillotina mira a las kaijus. Por fin, algo de su tamaño.*', 'WMEW 99.9: Tres monstruos en el mismo pueblo. La radio pide refuerzos.')
            'Averi'                = @('*Averi le da un sándwich. Guillotina decide no comérsela. Hoy.*', '*Huele a pollo. Viene de la zorrita.*')
            'Sebastian Solace'     = @('*Mira la cola de Sebastian. Parece un pescado enorme. Se relame.*', '*Sebastian le cobró por mirar. Ella se comió la caja registradora.*')
            'Pursuer'              = @('*Pursuer y Guillotina se miran. Uno come fresco, la otra come de todo.*', '*Pursuer desaparece. Guillotina abre la boca por si acaso.*')
            'Kasane Teto'          = @('*Guillotina mira las coletas de Teto. Parecen dos panes. Se relame.*', '*Teto baila delante de Guillotina. Guillotina la sigue con la mirada. Muy atenta. Demasiado atenta.*')
            'Token'                = @('*Guillotina intentó comerse a Token. Token siguió poniendo breakcore dentro.*', '*A Guillotina le gusta el bajo de Token. Le hace cosquillas en la barriga.*')
            'Tetra'                = @('*Guillotina se comió los fideos de Tetra. Y el vaso. Tetra ni se inmutó.*', '*Mira los pendientes de pez de Tetra. Se relame.*')
            'Kevin'                = @('*Mira la pizza de Kevin. Kevin la mira a ella. Nadie se mueve.*', '*Kevin le enseña los dientes. Guillotina le enseña los suyos. Kevin se va.*')
            'Kennyoung'            = @('*Guillotina se comió la guitarra de Kenny. Y el amplificador. Siguió sonando dentro.*', '*Mueve la cabeza al ritmo del pop-punk. Luego se come el altavoz.*')
            'Enfosi'               = @('*Guillotina mira la estatua de oro. Parece comestible.*', '*Se traga un Cheerer falso. Explota dentro. Guillotina eructa confeti.*')
            'Gran'                 = @('*Olfatea a Gran. Huele a hospital. No le gusta.*', '*Gran le ofrece la vacuna. Guillotina se come la vacuna, el brazo y la bata. Gran lo anota.*')
            'Nanachi'                = @('*Guillotina se comió el estofado de Nanachi. Entero. Es la única que lo ha disfrutado.*', '*Mira las orejas de Nanachi. Se relame. Nanachi le enseña un cucharón. Se aleja.*')
            'Evil Scary'             = @('*Guillotina intentó comerse a Evil Scary. Se le quedaron las manos fuera de la boca. Lo escupió.*', '*Por primera vez, Guillotina se esconde detrás de algo.*')
            'Soft Fuzzy Man'       = @('*Guillotina intentó comerse a Soft Fuzzy Man. Masticó aire. Se enfadó mucho.*', '*Guillotina le enseña los dientes. Él le guiña un ojo. Guillotina no sabe qué hacer.*')
        }
        Frases = @(
            '*ÑAM.*'
            '*Se lo ha tragado entero.*'
            '*Eructa.*'
            '*Sigue teniendo hambre.*'
            'WMEW 99.9: ¡Nadie está a salvo!'
        )
        Idle = @(
            '*Guillotina ronca. El suelo tiembla.*'
            '*Se lame una garra. Te mira.*'
            'WMEW 99.9: Se recomienda no salir de casa.'
            '*Su estómago ruge más fuerte que ella.*'
            '*Busca comida en tu papelera de reciclaje.*'
            'Su hambre no tiene fin.'
            '*Se ha sentado en el teclado. Ahora es suyo.*'
            'WMEW 99.9: Seguimos informando del gato gigante...'
            '*Persigue el cursor con la mirada.*'
            '*Huele tus archivos. Ninguno es comestible. De momento.*'
            '*Bosteza. Ves todos sus dientes.*'
            'WMEW 99.9: La casa de la colina sigue sin noticias.'
        )
        Clic = @(
            '*¡Le has dado! Se enfada.*'
            '*Gruñe. Eso no le ha gustado.*'
            '*Intenta comerse tu cursor.*'
            '*Bufa. Te arrepentirás.*'
            '*Te enseña los dientes.*'
        )
        PorApp = @{
            'YouTube'       = @('*Se come la pestaña de YouTube. Era un vídeo de pescado.*')
            'Word'          = @('*Mordisquea el documento. Le faltan tres páginas.*')
            'Excel'         = @('*Se traga una fila entera. Las celdas no sabían a nada.*')
            'PowerPoint'    = @('*Se sienta en la diapositiva 1. No piensa moverse.*')
            'Outlook'       = @('*Se come el correo antes de que lo leas.*')
            'OneNote'       = @('*Araña tus notas.*')
            'Access'        = @('*Engulle la base de datos. Le sienta mal.*')
            'Publisher'     = @('*Hace un póster: SE BUSCA COMIDA.*')
            'Teams'         = @('*Aparece en tu reunión. Todos huyen.*')
            'OneDrive'      = @('*Intenta comerse la nube. No puede. Se frustra.*')
            'Office Web'    = @('*Se traga el navegador de un bocado.*')
            'Bloc de notas' = @('*Escribe: ÑAMÑAMÑAMÑAMÑAM*')
            'Calculadora'   = @('*Calcula cuántos gatos caben en su estómago: muchos.*')
            'Explorador'    = @('*Explora tus carpetas buscando atún.*')
            'CMD'           = @('*Se come la pantalla negra. Era regaliz.*')
        }
    }
    # ================================================================ Angela (Lobotomy Corporation)
    'Angela' = @{
        Estilo = 'lobo'; Titulo = 'ANGELA'; Sub = "L Corp.  ·  DÍA $($script:dia)"; Alto = 312
        Fondo = (C 12 15 20); Borde = (C 255 170 40)
        TituloColor = (C 255 176 50); SubColor = (C 80 210 200)
        BtnFondo = (C 22 28 36); BtnTexto = (C 235 235 235); BtnTextoHover = (C 255 190 80); BtnBorde = (C 255 170 40); BtnBordeAncho = 1
        BtnHover = (C 60 44 16); BtnPress = (C 255 170 40); BarraBtnTexto = (C 255 176 50)
        StatusColor = (C 255 176 50); Fuente = 'Bahnschrift'; FuenteTitulo = 'Bahnschrift'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\angela\calma.png'
        Caras = @{
            cerrados = @('skins\angela\calma.png', 'skins\angela\habla.png')
            abiertos = @('skins\angela\abiertos.png', 'skins\angela\abiertos_habla.png')
            serio    = @('skins\angela\serio.png', 'skins\angela\serio_habla.png')
        }
        Pb = @(412, 66, 186, 148); PbFondo = (C 18 22 28); PbBorde = $false
        Burbuja = @(410, 222, 190, 72); BurFondo = (C 8 10 14); BurTexto = (C 255 190 90); BurFuente = 'Bahnschrift'
        Hola = @(
            'Buenos días, Manager. Comencemos con la jornada.'
            "Bienvenido, Manager. El día $($script:dia) empieza ahora."
            'Manager, sus aplicaciones están listas para ser asignadas.'
            'Recuerde, Manager: enfrente el miedo, construya el futuro.'
        )
        AlVenirDe = @{
            'c00lgui'     = 'Manager, he detectado una intrusión. Ya ha sido... neutralizada.'
            'SeaDrive'    = 'Ese asistente no cumple el protocolo. Yo me encargo a partir de ahora.'
            'Static Miku' = 'Las interferencias han sido eliminadas. Bienvenido de nuevo, Manager.'
            'Guillotina'  = 'Manager, la anomalía felina ha sido contenida. Por ahora.'
            'Mikaela'     = 'La francotiradora ha abandonado la instalación. Buenos días, Manager.'
            'Zodiac'      = 'Manager, el pistolero ha sido desarmado. Continúe.'
            'Velvet'      = 'Manager, la anomalía arácnida ha sido expulsada de la instalación.'
            'Dune'        = 'El espécimen acuático ha vuelto a su tanque. Continúe, Manager.'
            'Cordero y Cabra'      = 'Manager, el culto ha sido disuelto. He confiscado una corona sospechosa.'
            'Pyrophina y Zaratana' = 'Manager, las anomalías de clase kaiju se han marchado. Revise los daños.'
            'Averi'                = 'Manager, la empleada zorruna ha terminado su turno. Ha dejado migas.'
            'Sebastian Solace'     = 'Manager, el comerciante acuático ha cerrado. Revise su inventario.'
            'Pursuer'              = 'Manager, la entidad depredadora ha abandonado la instalación.'
            'Kasane Teto'          = 'Manager, la entidad cantante ha abandonado la instalación. Bailando.'
            'Token'                = 'Manager, la anomalía ruidosa ha abandonado la instalación. Los oídos de los empleados se recuperan.'
            'Tetra'                = 'Manager, el empleado Tetra ha finalizado su turno. Sin contestar al correo.'
            'Kevin'                = 'Manager, la anomalía verde ha abandonado la instalación. Ha dejado migas en el núcleo.'
            'Kennyoung'            = 'Manager, el músico Kennyoung ha abandonado la instalación. El nivel de ruido vuelve a la normalidad.'
            'Enfosi'               = 'Manager, la defensa de la estatua ha terminado. Registro de strikes: archivado.'
            'Gran'                 = 'Manager, el doctor de Antihuman Inc. ha abandonado la instalación. Ha dejado contratos sin firmar en recepción.'
            'Nanachi'                = 'Manager, Nanachi ha regresado a su escondite. Ha dejado un olor... agradable.'
            'Evil Scary'             = 'Manager, la entidad Evil Scary ha abandonado la instalación. Las paredes siguen... atravesadas.'
            'Soft Fuzzy Man'       = 'Manager, la entidad gaseosa ha abandonado la instalación. Los conductos de ventilación huelen a algodón de azúcar.'
        }
        Yo = @('Esa soy yo, Manager. La opción más eficiente.', 'Una elección lógica, Manager.')
        Opina = @{
            'c00lgui'     = @('c00lgui es un programa no autorizado. Lo tengo vigilado.', 'Ese "hacker" no superaría ni el primer día en L Corp.')
            'SeaDrive'    = @('SeaDrive es... ineficiente. Pero admito que tiene carácter.', 'Un asistente que se queja. Fascinante. Inútil, pero fascinante.')
            'Static Miku' = @('Static Miku emite demasiado ruido. Literalmente.', 'Su optimismo es admirable. Y sospechoso.')
            'Guillotina'  = @('Guillotina tendría clasificación HE como mínimo. Quizá WAW.', 'No permita que esa anomalía se acerque a los empleados.')
            'Mikaela'     = @('Mikaela: perfil de empleada eficiente. Demasiado ruidosa, eso sí.', 'Le ofrecí un puesto en L Corp. Se negó. Es libre de equivocarse.')
            'Zodiac'      = @('Zodiac sería una anomalía TETH. Peligroso, pero predecible.', 'Ese vaquero disparó a una cámara de seguridad. Se lo descontaré.')
            'Velvet'      = @('Velvet: riesgo ALEPH en lo personal. No la deje sola con los empleados.', 'Su voz está diseñada para atraer presas. No la escuche, Manager.')
            'Dune'        = @('Dune tiene la inteligencia de un pez y el apetito de diez.', 'Ese espécimen mordió la cámara de contención. Dos veces.')
            'Cordero y Cabra'      = @('Un culto con dos líderes. Ineficiente. Pero su nivel de fe es admirable.', 'La Cabra filtró una contraseña en público. Fallo de seguridad grave.')
            'Pyrophina y Zaratana' = @('Dos anomalías ALEPH peleando entre sí. Ojalá todas cooperaran así.', 'Manager, no intente contenerlas. No hay celda tan grande.')
            'Averi'                = @('Averi tiene buenas intenciones y una ejecución pésima. Como muchos empleados.', 'Me preguntó si soy feliz, Manager. No supe responder. Lo anoto.')
            'Sebastian Solace'     = @('Sebastian trabajó para una corporación. Lo noto en su forma de cobrar.', 'Su tienda no tiene licencia, Manager. Ni la va a tener.')
            'Pursuer'              = @('Pursuer: riesgo WAW. Invisible, rápido y con hambre. No lo provoque, Manager.', 'Esa entidad no deja registros en las cámaras. Inquietante.')
            'Kasane Teto'          = @('Kasane Teto: origen clasificado como "broma". Sin embargo, sigue aquí. Fascinante.', 'Teto ha confundido el botón de emergencia con un timbre. Tres veces.')
            'Token'                = @('Token: nivel de ruido fuera de escala. Clasificación: ALEPH. De volumen.', 'Token rompió tres medidores de decibelios. Se lo descontaré.')
            'Tetra'                = @('Tetra tiene 412 mensajes sin leer. Un récord en la instalación.', 'Tetra no causa incidentes. Tampoco los resuelve. Interesante.')
            'Kevin'                = @('Kevin: anomalía de tipo comida. Reacción violenta si se toca su pizza. No tocar.', 'Kevin ha mordido a tres agentes. Los tres tocaron la pizza. Patrón detectado.')
            'Kennyoung'            = @('Kennyoung: músico. Nivel de ruido: elevado. Productividad: discutible.', 'Kennyoung ha roto tres guitarras en la instalación. Se lo descontaré de su próxima gira.')
            'Enfosi'               = @('Los Enphosians imitan a los Glaggles con pequeñas imperfecciones. Muy eficiente.', 'El Ojo de Enphoso no admite contención. Lo he intentado.')
            'Gran'                 = @('Gran crea anomalías a propósito. En L Corp eso se llama "infracción grave".', 'Me ha pedido muestras de nuestras Abnormalities. He denegado la solicitud. Tres veces.')
            'Nanachi'                = @('Nanachi conoce la medicina mejor que nuestro equipo de bienestar. Inquietante.', 'Clasificación de Nanachi: no es una anomalía. Me lo ha dejado muy claro.')
            'Evil Scary'             = @('Evil Scary: clasificación imposible. Atraviesa la contención. No responde a nada.', 'He intentado razonar con Evil Scary. Me ha contestado "STALL, STALL".')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man: riesgo bajo. Insistencia alta. Me ha piropeado tres veces.', 'No hay celda para un gas que liga.')
        }
        Frases = @(
            'Tarea asignada. Le recomiendo no perder el tiempo.'
            'Aplicación en funcionamiento, Manager.'
            'Registrado. Su productividad está siendo evaluada.'
            'Como ordene, Manager.'
        )
        Idle = @(
            'Manager, la cuota de energía no se completará sola.'
            'Le estoy observando, Manager. Es parte de mi trabajo.'
            'Todo está bajo control. No hay de qué preocuparse.'
            'He calculado su eficiencia de hoy. Prefiero no comentarla.'
            'Los empleados necesitan descansar. Usted también, Manager.'
            'Un buen Manager no deja tareas pendientes.'
            'Si algo sale mal, siempre podemos empezar el día otra vez.'
            'Mantenga la calma. El pánico reduce la productividad.'
            'Hidrátese. Un Manager deshidratado es un Manager ineficiente.'
            'La instalación funciona con normalidad. Por ahora.'
            'He archivado sus pestañas abiertas. Eran demasiadas.'
            'Manager... ¿alguna vez se ha preguntado qué soy?'
        )
        Clic = @(
            '¿Necesita algo, Manager?'
            'Por favor, no toque la pantalla.'
            'Estoy aquí, Manager. Siempre lo estoy.'
            'Sus clics han sido registrados.'
        )
        PorApp = @{
            'YouTube'       = @('YouTube. Lo registraré como "tiempo de descanso".', 'Manager, 10 minutos. Ni uno más.')
            'Word'          = @('Redacte su informe con precisión, Manager.')
            'Excel'         = @('Excelente. Los datos nunca mienten.', 'Las hojas de cálculo son la base de toda buena gestión.')
            'PowerPoint'    = @('Presentación preparada. Que sea breve.')
            'Outlook'       = @('Tiene correspondencia pendiente, Manager.')
            'OneNote'       = @('Tome notas. La memoria es frágil.')
            'Access'        = @('Base de datos abierta. Mi especialidad.')
            'Publisher'     = @('Publicaciones internas. Recuerde el manual de estilo de L Corp.')
            'Teams'         = @('Reunión iniciada. Mantenga la compostura.')
            'OneDrive'      = @('Sus archivos están a salvo en la nube. Yo también los vigilo.')
            'Office Web'    = @('Acceso web concedido.')
            'Bloc de notas' = @('Un registro simple. Eficiente.')
            'Calculadora'   = @('Puedo calcular eso más rápido, pero adelante.')
            'Explorador'    = @('Explorando el sistema de archivos. No se pierda, Manager.')
            'CMD'           = @('Terminal abierto. Espero que sepa lo que hace.')
        }
    }
    # ================================================================ Mikaela (PURSUITCORE)
    'Mikaela' = @{
        Estilo = 'mlg'; Titulo = ''; TituloImg = 'skins\mikaela\placa.png'; Sub = 'THE MVP  ·  PURSUITCORE'; Alto = 312
        Fondo = (C 30 30 60); Borde = (C 0 255 0)
        TituloColor = (C 255 255 255); SubColor = (C 191 239 255)
        BtnFondo = (C 12 12 24); BtnTexto = (C 255 255 255); BtnTextoHover = (C 0 0 0); BtnBorde = (C 0 255 0); BtnBordeAncho = 2
        BtnHover = (C 0 230 0); BtnPress = (C 229 45 45); BarraBtnTexto = (C 0 255 0)
        StatusColor = (C 191 239 255); Fuente = 'Arial Black'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 2
        Gif = 'skins\mikaela\retrato.png'; GifClic = 'skins\mikaela\peligro.png'
        Sonidos = @{
            apuntar = @('skins\mikaela\apuntar.mp3'); carga = @('skins\mikaela\carga.mp3'); sobrecarga = @('skins\mikaela\sobrecarga.mp3')
            disparo = @('skins\mikaela\disparo.mp3'); disparoMax = @('skins\mikaela\disparo_max.mp3')
            humo = @('skins\mikaela\humo.mp3'); dew = @('skins\mikaela\dew.mp3')
        }
        Pb = @(410, 62, 190, 150); PbFondo = (C 0 0 0); PbBorde = $false
        Burbuja = @(410, 232, 190, 64); BurFondo = (C 8 8 16); BurTexto = (C 0 255 0); BurFuente = 'Arial'
        Hola = @(
            '¡Mikaela en el servidor! ¿Quién quiere un 360 no scope?'
            'La MVP ha llegado. Podéis aplaudir.'
            'Gafas puestas, rifle cargado. ¿Qué abrimos?'
            'Raze Snipers reportándose. Hola.'
        )
        AlVenirDe = @{
            'c00lgui'     = '¡Fuera hackers! Aquí se gana con habilidad.'
            'SeaDrive'    = 'Adiós al tutorial de 40 minutos. Hola a la acción.'
            'Static Miku' = 'Por fin silencio. Perfecto para apuntar.'
            'Guillotina'  = '¿La gata gigante? Ya la he estuneado. De nada.'
            'Angela'      = 'He escapado de L Corp. Sin un rasguño.'
            'Zodiac'      = 'Duelo terminado. Gané yo, claro.'
            'Velvet'      = 'He limpiado la telaraña de mi mira. Ya puedo apuntar otra vez.'
            'Dune'        = 'Adiós al bicho de arena. Me había mojado el rifle.'
            'Cordero y Cabra'      = 'Adiós al culto. Yo no sigo a nadie. Me siguen a mí.'
            'Pyrophina y Zaratana' = 'Las kaijus se han ido. Mis balas no les hacían nada. Lag, seguro.'
            'Averi'                = 'Averi se ha ido. Me dejó un sándwich. GG.'
            'Sebastian Solace'     = 'Adiós al tendero. Me vendió munición caducada.'
            'Pursuer'              = 'Se fue el del bosque. No me dio tiempo ni a apuntar.'
            'Kasane Teto'          = 'Se fue la de los taladros. No pude ni apuntarle, no se estaba quieta.'
            'Token'                = 'Se fue Token. Mis hitmarkers vuelven a oírse. GG.'
            'Tetra'                = 'Tetra se ha desconectado. Ni AFK, directamente offline.'
            'Kevin'                = 'Kevin se ha desconectado. Rage quit por una pizza. Clásico.'
            'Kennyoung'            = 'Kenny se ha desconectado. GG por el concierto.'
            'Enfosi'               = 'Fin de las oleadas. Ningún Glaggle inocente herido. Casi ninguno.'
            'Gran'                 = 'Se ha ido el de la jeringuilla. Le tenía en la mira todo el rato.'
            'Nanachi'                = 'Nanachi se ha ido. Me curó el dedo del gatillo. GG.'
            'Evil Scary'             = 'Evil Scary se ha ido. 0 hitmarkers en toda la partida. Primera vez.'
            'Soft Fuzzy Man'       = 'Soft Fuzzy Man se ha ido. Le hice un noscope. La bala salió por el otro lado. 0 de daño. Me dio las gracias.'
        }
        Yo = @('Esa soy yo. La MVP. Obviamente.', '¿Mikaela? Elección de pro.')
        Opina = @{
            'c00lgui'     = @('¿c00lkidd? Un script kiddie. Le haría headshot desde el otro lado del mapa.', 'Su panel es rojo y negro. Clásico de 2006. Respeto.')
            'SeaDrive'    = @('SeaDrive también es una gata. Pero yo tengo un rifle.', 'Le pedí a SeaDrive un buen spot de francotiradora. Me dio un tutorial de 40 minutos.')
            'Static Miku' = @('Static Miku hace mucho ruido. Delata mi posición.', 'Me gustan sus colores. Casi tan llamativos como mi abrigo.')
            'Guillotina'  = @('Guillotina es un objetivo enorme. Imposible fallar.', 'Le disparé a Guillotina. Se comió la bala.')
            'Angela'      = @('Angela me ofreció trabajo en L Corp. Paso, gracias.', 'Angela da más miedo que cualquier Terminator.')
            'Zodiac'      = @('Zodiac dispara a todo lo que se mueve. Amateur. Yo elijo mis objetivos.', 'Seis balas y un revólver. Mi Intervention se ríe.')
            'Velvet'      = @('Velvet tiene un subfusil y ocho patas. Respeto. De lejos.', 'Le hice headshot a Velvet. Se regeneró. Qué asco.')
            'Dune'        = @('Dune intentó comerse mi Intervention. Sin cubiertos.', 'Ese bicho nada más rápido de lo que yo corro. Injusto.')
            'Cordero y Cabra'      = @('Le disparé a la corona de la Cabra. Rebotó. Ahora somos amigas.', 'El Cordero me ofreció ser cruzada. Solo si puedo llevar mi Intervention.')
            'Pyrophina y Zaratana' = @('Objetivos enormes. Imposible fallar. Imposible tumbarlas, también.', 'Zaratana tiene caparazón. Mis headshots rebotan. Injusto.')
            'Averi'                = @('Averi me pidió clases de puntería. Le dio a una lámpara. Tiene potencial.', 'Si alguien molesta a Averi, le hago headshot. Es mi colega.')
            'Sebastian Solace'     = @('Sebastian vende pilas. Yo necesito pilas para la mira. Es mi proveedor.', 'Le pregunté si tenía una Intervention. Me ofreció una linterna.')
            'Pursuer'              = @('Pursuer se vuelve invisible. Mis hitmarkers no sirven contra lo que no veo.', 'Le hice headshot a Pursuer. Se rió. O eso creo.')
            'Kasane Teto'          = @('Teto baila tan raro que mis hitmarkers no la siguen. Respeto.', 'Le hice un noscope a Teto. Me dijo "hiii". Ni se enteró.')
            'Token'                = @('Token tiene un drop mejor que mi Intervention. Me duele decirlo.', 'Le hice un 360 noscope a Token. Ni se enteró. Siguió bailando.')
            'Tetra'                = @('Tetra juega sin presión. Rango: madera. Felicidad: diamante.', 'Le pasé el mando a Tetra. Se puso a comer fideos. Respeto.')
            'Kevin'                = @('Le hice un noscope a la pizza de Kevin. Me persiguió con una motosierra. Respeto.', 'Kevin grita más que un niño en el chat de voz. Y eso es mucho.')
            'Kennyoung'            = @('Kenny me hizo una canción para mis clips. Ahora mis noscopes tienen batería.', 'Kenny rompe guitarras como yo rompo récords. Respeto.')
            'Enfosi'               = @('Le di un headshot a un Gazo falso. Hitmarker. El juego dice que hace daño extra.', 'Distinguir un Enphosian por la camiseta. Eso es puntería de verdad.')
            'Gran'                 = @('Gran me quería dar la vacuna. Le dije que mi única vacuna es un headshot.', 'Si me convierte en furry, ¿me sube la puntería? ...no lo pregunto en serio.')
            'Nanachi'                = @('Nanachi ve cosas que nadie ve. Sería el mejor apoyo de cualquier equipo.', 'Probé su estofado. Primera vez que pierdo contra una comida.')
            'Evil Scary'             = @('Evil Scary no tiene hitbox. O sí, pero no sirve de nada. GG, supongo.', 'Le hice una Smokebomb. Me encontró en dos segundos. Ve a través de todo.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man no tiene hitbox. Es un fallo del juego con sentimientos.', 'Mi Smokebomb y él se hicieron amigos. Ahora hay el doble de humo.')
        }
        Frases = @(
            '¡Hitmarker!'
            'Headshot. Fácil.'
            '+100 puntos de estilo.'
            'Ni he apuntado. Así de buena soy.'
            'GG EZ.'
        )
        Idle = @(
            'Ningún Terminator a la vista... por ahora.'
            'Dante dice que campeo mucho. Dante no sabe apuntar.'
            'Vinnie me debe un refresco.'
            'Nyan sigue intentando hacerme reír en mitad de una partida.'
            'Mi rifle es una Intervention. Elegancia pura.'
            'Estoy en mi posición de francotiradora. No me muevo.'
            'Mis gafas lima no son para el sol. Bueno, un poco sí.'
            'Si oyes un disparo a lo lejos... fui yo.'
            'Estilo y precisión. Mi lema.'
            'Me aburro. ¿Hay algún Terminator al que disparar?'
            'Respira, apunta, dispara. Fácil.'
            'Mi camiseta tiene una Awesome Face. Obviamente.'
            'Mantén pulsado sobre mí para cargar el tiro. Suelta para disparar.'
        )
        Clic = @('GG EZ.', '¡Toma ya!', 'Ni lo ha visto venir.', 'Clip para el montaje.', 'Raze Snipers, baby.')
        PorApp = @{
            'YouTube'       = @('YouTube: a ver mis montajes de 360 no scope.', 'Pon un vídeo de PURSUITCORE, anda.')
            'Word'          = @('Escribe mi biografía. Título: "La MVP".')
            'Excel'         = @('Una hoja con mis headshots. Necesitarás más filas.')
            'PowerPoint'    = @('Diapositiva 1: por qué soy la mejor francotiradora.')
            'Outlook'       = @('Correo de Dante: "deja de campear". Ignorado.')
            'OneNote'       = @('Notas de táctica: apuntar a la cabeza. Fin.')
            'Access'        = @('Base de datos de Terminators abatidos. Está llena.')
            'Publisher'     = @('Póster de "Únete a Raze Snipers".')
            'Teams'         = @('Reunión de equipo. Yo cubro desde atrás.')
            'OneDrive'      = @('Subiendo mis clips a la nube. Todos son jugadones.')
            'Office Web'    = @('Abriendo en el navegador. Rápido como un hitscan.')
            'Bloc de notas' = @('Bloc de notas: mi lista de kills.')
            'Calculadora'   = @('Calculando la trayectoria... era recta. Hitscan.')
            'Explorador'    = @('Buscando un buen spot de francotiradora en tus carpetas.')
            'CMD'           = @('Hackeando el servidor... es broma, eso es cosa de c00lkidd.')
        }
    }
    # ================================================================ Zodiac (Mewgenics)
    'Zodiac' = @{
        Estilo = 'oeste'; Titulo = 'ZODIAC'; Sub = 'the desert  ·  mewgenics'; Alto = 312
        Fondo = (C 236 196 130); Borde = (C 60 34 18)
        TituloColor = (C 250 225 170); SubColor = (C 240 160 70)
        BtnFondo = (C 128 80 42); BtnTexto = (C 250 236 205); BtnTextoHover = (C 250 236 205); BtnBorde = (C 55 32 16); BtnBordeAncho = 2
        BtnHover = (C 176 112 56); BtnPress = (C 200 60 30); BarraBtnTexto = (C 250 236 205)
        StatusColor = (C 250 236 205); Fuente = 'EdmundMcMillen_INTLv4'; FuenteTitulo = 'EdmundMcMillen_INTLv4'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\zodiac\z_idle.gif'
        FondoImg = 'skins\zodiac\desierto.jpg'; IntroImg = 'skins\zodiac\coche.jpg'
        Actores = @(
            @{ Id = 'Z'; Gif = 'skins\zodiac\z_idle.gif'; Rect = @(476, 62, 240, 192)
               Extra = @{ clic = 'skins\zodiac\z_disparo.gif'; vacio = 'skins\zodiac\z_vacio.gif'; recarga = 'skins\zodiac\z_recarga.gif'; pose = 'skins\zodiac\z_pose.gif'; muere = 'skins\zodiac\z_muere.gif' } }
        )
        Cartel = 'skins\zodiac\cartel_z.png'
        Sonidos = @{
            loco = @('skins\zodiac\loco1.wav', 'skins\zodiac\loco2.wav', 'skins\zodiac\loco3.wav', 'skins\zodiac\loco4.wav')
            bang = @('skins\zodiac\s_bang.wav'); grito = @('skins\zodiac\s_grito1.wav', 'skins\zodiac\s_grito2.wav', 'skins\zodiac\s_grito3.wav')
            recarga = @('skins\zodiac\s_recarga.wav'); recargav = @('skins\zodiac\s_recargav1.wav', 'skins\zodiac\s_recargav2.wav')
            vacio = @('skins\zodiac\s_vacio.wav'); dolor = @('skins\zodiac\s_dolor1.wav', 'skins\zodiac\s_dolor2.wav'); muere = @('skins\zodiac\s_muere.wav')
            aparece = @('skins\zodiac\s_aparece.wav'); viento = @('skins\zodiac\viento.wav')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 245 230 196); BurTexto = (C 60 34 18); BurFuente = 'TikaFont Adjusted'
        Hola = @(
            '¡No te muevas! ...Vale, hola.'
            '*Zodiac te apunta con el revólver.* ¿Qué quieres, forastero?'
            'Seis balas. Un vaquero. Un escritorio. Esto va a acabar mal.'
            '*Escupe en el suelo del escritorio.*'
        )
        AlVenirDe = @{
            'c00lgui'     = '¡Ese panel rojo se movía mucho! Ya no se mueve.'
            'SeaDrive'    = '*Sopla el humo del revólver.* La gata se ha ido.'
            'Static Miku' = '¡Le disparé a la tele! ...se apagó sola.'
            'Guillotina'  = 'Guillotina me ha dejado el desierto libre. Por ahora.'
            'Angela'      = 'Escapé de esa instalación gris. Nadie se movía. Horrible.'
            'Mikaela'     = 'Duelo terminado. La francotiradora no aguantó el cara a cara.'
            'Velvet'      = '*Se quita telarañas del sombrero.* Mala vecina.'
            'Dune'        = 'El bicho de arena se ha ido. Mi desierto vuelve a estar seco.'
            'Cordero y Cabra'      = 'El culto se ha ido. La cabra gritaba más que yo. Inaceptable.'
            'Pyrophina y Zaratana' = '*Sale de debajo de una piedra.* ¿Ya se han ido esos monstruos? Uf.'
            'Averi'                = 'La zorrita se fue. Me dio un abrazo. Todavía no sé qué hacer con eso.'
            'Sebastian Solace'     = 'El tendero se ha ido. Le debía seis balas.'
            'Pursuer'              = '*Mira al bosque.* Algo se movía ahí. Ya no se mueve.'
            'Kasane Teto'          = 'La de las coletas se ha ido. Bailaba demasiado para dispararle.'
            'Token'                = 'El gato ruidoso se ha ido. Por fin oigo el viento del desierto.'
            'Tetra'                = 'Tetra se ha ido. Ni se movió en todo el rato. Mi cliente favorito.'
            'Kevin'                = 'El lobo verde se fue. Se llevó la pizza. Ni un trozo para el sheriff.'
            'Kennyoung'            = 'El de la guitarra se fue. Por fin silencio en el desierto.'
            'Enfosi'               = 'Se acabaron los Glaggles. Por fin puedo disparar a lo que se mueva sin strikes.'
            'Gran'                 = '¡Se ha ido el de la bata verde! Que no vuelva con esa aguja.'
            'Nanachi'                = 'El conejo del Abismo se fue. Me curó la mano. No le disparé. Es un detalle.'
            'Evil Scary'             = 'La bola negra se fue. Seis balas. Cero agujeros. Me voy a echar una siesta.'
            'Soft Fuzzy Man'       = 'La nube rosa se fue. Seis balas. Seis agujeros en el aire. Ni uno en él.'
        }
        Yo = @('*Se mira en el reflejo del revólver. Asiente.*', 'El mejor pistolero del desierto. Ese soy yo.')
        Opina = @{
            'c00lgui'     = @('¿Un hacker? En mis tiempos los forajidos daban la cara.', '*Le dispara al panel rojo. Sigue funcionando. Qué raro.*')
            'SeaDrive'    = @('Esa gata de los auriculares habla demasiado.', 'SeaDrive me dio un consejo. Le disparé. Al consejo.')
            'Static Miku' = @('¡Esa tele no deja de moverse! ¡BANG!', 'La chica de las coletas siempre sonríe. Sospechoso.')
            'Guillotina'  = @('Guillotina y yo somos del mismo juego. Ella come, yo disparo.', 'Le disparé a Guillotina seis veces. Se comió las seis balas.')
            'Angela'      = @('La dama de L Corp no se mueve nunca. No puedo dispararle. Me frustra.')
            'Mikaela'     = @('¿La francotiradora? Buena puntería. Para ser de Roblox.', 'Un rifle de francotirador... de cobardes. Los duelos se hacen cara a cara.')
            'Velvet'      = @('La araña no se mueve hasta que es tarde. Me pone nervioso.', 'Velvet me invitó a cenar. Yo era la cena.')
            'Dune'        = @('Dune vive en el agua. En el desierto. No tiene sentido.', '¡Ese bicho se mueve demasiado! ¡BANG!')
            'Cordero y Cabra'      = @('¡Esa cabra se ha movido! *BANG* ...y se ríe. Da miedo.', 'El Cordero no habla. Me gusta. La Cabra... en el fondo también.')
            'Pyrophina y Zaratana' = @('Seis balas contra dos kaijus. Las cuentas no salen.', 'Pyrophina me lanzó contra Zaratana. Dos veces. "No te muevas", dije. Se movió.')
            'Averi'                = @('La zorrita me abrazó cuando le apunté. Nadie hace eso.', 'Averi dice que necesito una siesta y un sándwich. ...Puede que tenga razón.')
            'Sebastian Solace'     = @('Ese pez se queda quieto en el mostrador. No le puedo disparar. Lo odio.', 'Sebastian me vendió un revólver de agua. Era una broma. No me reí.')
            'Pursuer'              = @('¡No te muevas, Pursuer! ...¿Dónde está? ¡NO ESTÁ!', 'Ese no hace ruido al moverse. No es justo.')
            'Kasane Teto'          = @('¡No te muevas, Teto! ...está bailando. NO PUEDE NO MOVERSE.', 'Le disparé al suelo para que bailara. Ya estaba bailando. No ayudó.')
            'Token'                = @('¡No te muevas, Token! ...vibra. Vibra todo el rato. NO PUEDO.', 'Le disparé seis veces al altavoz de Token. Siguió sonando. Brujería.')
            'Tetra'                = @('Tetra no se mueve del sofá. Es el único al que nunca le disparo.', 'Le dije a Tetra "no te muevas". Me dijo "tranqui". Y no se movió. Respeto.')
            'Kevin'                = @('¡No te muevas, lobo! ...me dijo "no toques mi pizza". Tablas.', 'Kevin tiene un cuchillo y una pistola. Yo tengo seis balas. Duelo pendiente.')
            'Kennyoung'            = @('¡No te muevas, músico! ...me ha dicho que está en pleno concierto. Lo dejo pasar.', 'Kenny toca demasiado rápido. Mis balas no le pillan el ritmo.')
            'Enfosi'               = @('En Enfosi no se dispara a todo lo que se mueve. No lo entiendo. No me gusta.', 'Le disparé a un Giggler. Era inocente. Vino un ojo gigante. Me fui.')
            'Gran'                 = @('¡Ese doctor me apuntó con una jeringuilla! ¡NO TE MUEVAS! ...me movió él a mí.', 'Dice que ya soy un gato y que no hay nada que mejorar. Me lo tomo como un cumplido.')
            'Nanachi'                = @('Ese conejo me dijo que si no te mueves te comen. Ahora no sé qué hacer con mi vida.', 'Nanachi me vendó la mano sin preguntar. Gente así no queda en el oeste.')
            'Evil Scary'             = @('¡No te muevas, bola! ...SE MUEVE. A SALTOS. ¡NO LO SOPORTO!', 'Es lo único del oeste que corre más que mis balas. Y no corre. Bota.')
            'Soft Fuzzy Man'       = @('¡No te muevas! ...¡NO SE MUEVE, FLOTA! ¡ES PEOR!', 'Me dio las gracias por dispararle. Este oeste está fatal.')
        }
        Frases = @(
            '¡BANG!'
            '*Abre la app de un balazo.*'
            '¡Toma plomo!'
            '*Sopla el humo del cañón.*'
        )
        Idle = @(
            '*Vigila el horizonte del escritorio.*'
            '¡Algo se ha movido! ...era el cursor.'
            'En el desierto no hay Wi-Fi, forastero.'
            '*Hace girar el tambor del revólver.*'
            'Este escritorio es demasiado pequeño para los dos.'
            'No me gusta cómo me mira esa papelera de reciclaje.'
            '*Se ajusta el sombrero.*'
            'El sol del desierto me ha frito el cerebro. Más de lo normal.'
            '¿Has oído eso? Yo tampoco. Pero dispararé igual.'
            '*Tararea una canción solitaria del Oeste.*'
            'Tengo seis balas y cero paciencia.'
            'Si mueves la ventana, disparo. Avisado estás.'
        )
        Clic = @('*Pose de vaquero. Muy guapo.*', '*Hace girar el revólver en el dedo.*', 'No me toques, forastero.')
        PorApp = @{
            'YouTube'       = @('*Le dispara al botón de play.* ¡Reproducido!')
            'Word'          = @('*Agujerea el documento.* Ahora tiene ventilación.')
            'Excel'         = @('¡Celda A1, manos arriba!')
            'PowerPoint'    = @('*Dispara a cada diapositiva.* Presentación terminada.')
            'Outlook'       = @('¡Ese correo se ha movido! *BANG*')
            'OneNote'       = @('*Apunta tus notas. Con el revólver.*')
            'Access'        = @('¡Esa base de datos me parece sospechosa!')
            'Publisher'     = @('Haré un cartel de SE BUSCA. Con mi cara.')
            'Teams'         = @('¡Que nadie se mueva en la reunión!')
            'OneDrive'      = @('¿Una nube? Le dispararé hasta que llueva.')
            'Office Web'    = @('*Entra en el saloon de internet de una patada.*')
            'Bloc de notas' = @('Escribe tu testamento, forastero.')
            'Calculadora'   = @('6 balas menos 1... quedan 5. Sé contar.')
            'Explorador'    = @('*Explora tus carpetas como un forajido.*')
            'CMD'           = @('Pantalla negra como la noche del desierto.')
        }
    }
    # ================================================================ Velvet (Gunsaw)
    'Velvet' = @{
        Estilo = 'gunsaw'; Titulo = 'Velvet'; Sub = '14/14 species unlocked  ·  GUNSAW'; Alto = 312
        Fondo = (C 26 14 30); Borde = (C 10 4 12); Acento = (C 230 30 50)
        TituloColor = (C 224 220 228); SubColor = (C 170 160 180)
        BtnFondo = (C 36 22 40); BtnTexto = (C 226 222 230); BtnTextoHover = (C 255 255 255); BtnBorde = (C 125 112 130); BtnBordeAncho = 1
        BtnHover = (C 130 20 40); BtnPress = (C 230 30 50); BarraBtnTexto = (C 226 222 230)
        StatusColor = (C 226 222 230); Fuente = 'Consolas'; FuenteTitulo = 'Consolas'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\velvet\retrato.png'; Arte = 'skins\velvet\arte.png'; Arma = 'SMG'; Telarana = $true
        Pb = @(410, 62, 190, 150); PbFondo = (C 26 14 30); PbBorde = $false
        Burbuja = @(410, 232, 190, 64); BurFondo = (C 18 9 22); BurTexto = (C 230 225 235); BurFuente = 'Consolas'
        IntroLineas = @(
            '- Una extraña criatura femenina parecida a una araña.'
            '- 4 patas enormes le crecen de la espalda. Solo'
            '  sirven para dar miedo.'
            '- Escupe telarañas densas para inmovilizar presas.'
            '- Usa su voz maternal para atraer a los demás...'
            'Si te escupe, aguanta. Cuidado con su resistencia.'
        )
        IntroStats = @('Aim speed: {r}90%{b}   Move speed: {r}93%', 'Reload speed: {r}90%{b}   Health: {g}120')
        IntroPie = @('Tanky, with bad weapon handling', '{g}Hold CTRL/LMB to spit out cobweb')
        Hola = @(
            'Hola, cielo... ¿has venido a visitarme? Qué detalle.'
            'Pasa, pasa... no muerdo. Mucho.'
            'Mi pequeña presa favorita ha vuelto. Digo... mi usuario favorito.'
            'Bienvenido a mi telaraña, cariño.'
        )
        AlVenirDe = @{
            'c00lgui'     = 'Ese hacker hacía mucho ruido. Aquí estarás tranquilo, cielo.'
            'SeaDrive'    = 'Ay, esa gatita gruñona... sabría deliciosa. Digo, es muy simpática.'
            'Static Miku' = 'Qué tele tan ruidosa... aquí todo es calma. Y seda.'
            'Guillotina'  = 'Esa gata se lo comía todo. Qué modales. Yo juego primero con la comida.'
            'Angela'      = 'L Corp no me quiso. Dijeron que era "demasiado peligrosa". Exagerados.'
            'Mikaela'     = 'La francotiradora se ha ido. Mejor, ese punto rojo me ponía nerviosa.'
            'Zodiac'      = 'El vaquero se ha ido. Lástima, olía a cecina.'
            'Dune'        = 'Dune se ha ido... ese bobo siempre se come la comida sin jugar con ella.'
            'Cordero y Cabra'      = 'El culto se ha ido, cielo. Rechacé ser obispa. Por ahora.'
            'Pyrophina y Zaratana' = 'Las grandotas se han ido. Me rompieron tres telarañas. Qué groseras.'
            'Averi'                = 'La zorrita se fue antes del postre. Qué pena. Ella era el postre.'
            'Sebastian Solace'     = 'El tendero se ha ido, cielo. Me hacía la competencia atrayendo clientes.'
            'Pursuer'              = 'El cazador del bosque se fue. Qué pena, teníamos tanto en común.'
            'Kasane Teto'          = 'La cantante se ha ido, cielo. Qué voz tan... apetecible.'
            'Token'                = 'El gatito ruidoso se fue, cariño. Mi telaraña dejó de vibrar.'
            'Tetra'                = 'Tetra se ha ido, cielo. Me dejó en visto. Qué descaro tan... tentador.'
            'Kevin'                = 'Kevin se ha ido, cielo. Qué pena... olía a pizza y a peligro.'
            'Kennyoung'            = 'Kenny se ha ido, cielo. Qué pena... tocaba tan bien.'
            'Enfosi'               = 'Los Glaggles se han ido, cariño. Tan sonrientes... tan apetecibles.'
            'Gran'                 = 'El doctor se ha ido, cariño. Qué hombre tan frío... me encanta.'
            'Nanachi'                = 'Nanachi se ha ido, cielo. Tanto pelo mullido... y tanta desconfianza. Una pena.'
            'Evil Scary'             = 'Evil Scary se ha ido, cielo. Por primera vez, alguien me ha dado miedo a mí.'
            'Soft Fuzzy Man'       = 'Soft Fuzzy Man se ha ido, cielo. Por fin alguien que liga más que yo. Me ha ganado.'
        }
        Yo = @('Esa soy yo, cielo. ¿Verdad que soy preciosa?', 'Elígeme a mí, cariño. Te trataré muy bien.')
        Opina = @{
            'c00lgui'     = @('c00lkidd es como una mosca: hace ruido y acaba en mi telaraña.', '¿Un hacker? Qué mono. Lo guardaré para la cena.')
            'SeaDrive'    = @('SeaDrive es una gatita adorable. Y tierna. Muy tierna.', 'Invité a SeaDrive a tomar el té. No vino. Lista.')
            'Static Miku' = @('Qué niña tan alegre... me encantaría tenerla en mi colección.', 'Su tele hace demasiado ruido para mi gusto, cielo.')
            'Guillotina'  = @('Guillotina come sin elegancia. A la presa hay que saborearla.', 'Ella y yo nos parecemos. Pero yo tengo mejores modales.')
            'Angela'      = @('Angela no tiene sangre. Qué decepción.', 'Esa máquina me mira como si fuera una anomalía. Qué grosera.')
            'Mikaela'     = @('La niña del rifle... tan valiente. Tan sabrosa.', 'Dispara desde lejos porque sabe lo que pasa de cerca.')
            'Zodiac'      = @('El vaquero dispara a todo lo que se mueve. Yo espero a que deje de moverse.', 'Seis balas no bastan para una araña, cariño.')
            'Dune'        = @('Dune es mi primo bobo. Come sin jugar con la comida. Qué desperdicio.', 'A veces cazamos juntos. Nunca me deja nada.')
            'Cordero y Cabra'      = @('El Cordero es tan tierno... y tan esponjoso. Me dan ganas de envolverlo.', 'Me ofrecieron ser obispa del culto. Me lo estoy pensando, cariño.')
            'Pyrophina y Zaratana' = @('Demasiado grandes para mi telaraña. Qué frustrante.', 'Pyrophina quemó mi telaraña. Le guardo rencor. Mucho.')
            'Averi'                = @('Averi me dijo que tengo patas bonitas. Ocho veces. Qué niña tan dulce.', 'La zorrita huele a pollo. Qué apetitosa. Digo... qué simpática.')
            'Sebastian Solace'     = @('Sebastian y yo atraemos a la gente con voz dulce. Él para cobrarles. Yo para cenármelos.', 'Su cola es preciosa, cariño. Qué envoltorio tan bonito daría.')
            'Pursuer'              = @('Pursuer persigue. Yo espero. Ambos acabamos comiendo.', 'Le invité a cenar. Dijo que solo come fresco. Qué exigente.')
            'Kasane Teto'          = @('Teto tiene cerebro de pájaro, cariño. Y a mí me encantan los pajaritos.', 'Le invité a mi telaraña. Pensó que era una pista de baile.')
            'Token'                = @('Token gritó "DINNER!" en mi casa. Era yo la que iba a decir eso, cielo.', 'La telaraña no aguanta los drops de Token. Tengo que reforzarla.')
            'Tetra'                = @('Tetra tiene pendientes de pez, cariño. Me abren el apetito.', 'Tetra no contesta mis mensajes. Me gusta la gente difícil.')
            'Kevin'                = @('Kevin, cariño, es tan tierno cuando se enfada... casi me lo como.', 'Le toqué la pizza a Kevin. Sacó una motosierra. Me encanta este chico.')
            'Kennyoung'            = @('Kenny, cariño, me encantaría que me dedicara una canción. Y luego invitarle a cenar.', 'Kenny siempre tiene ensayo cuando lo invito a cenar. Qué casualidad, cielo.')
            'Enfosi'               = @('Los Enphosians se disfrazan para acercarse. Qué técnica tan elegante, cielo.', 'Atrapé a un Cheerer en mi telaraña. Era falso. Explotó. Ahora no tengo telaraña.')
            'Gran'                 = @('Gran admira mis ocho patas. Es el primer hombre que me mira con interés científico, cielo.', 'Le invité a mi telaraña. Me pidió una muestra de seda. Qué romántico.')
            'Nanachi'                = @('Nanachi huele a algodón de azúcar, cariño. Es muy injusto.', 'Me miró como si supiera lo que pienso. Igual lo sabía.')
            'Evil Scary'             = @('Esa bola sonríe más que yo, cariño. Y eso es mucho decir.', 'Le ofrecí cenar. Botó hacia mí. Cancelé la cena.')
            'Soft Fuzzy Man'       = @('Ese chico de niebla es todo palabras, cariño. Ni siquiera tiene manos para cogerte las tuyas.', 'Le tejí una telaraña. La atravesó guiñando un ojo. Qué descaro. Me encanta.')
        }
        Frases = @(
            'Listo, cielo. Tómate tu tiempo... yo esperaré.'
            'Ya está abierto, cariño. Ahora quédate quietecito.'
            'Qué buen chico. Así me gusta.'
            'Hecho. ¿Ves? Puedo ser muy dulce.'
        )
        Idle = @(
            'Estoy tejiendo... algo especial para ti.'
            'Tranquilo, cielo. Mis patas de la espalda son solo decoración.'
            '¿Tienes frío? Puedo envolverte en seda.'
            'Qué silencio... me encanta cuando la presa se queda quieta.'
            'Mi voz es dulce, ¿verdad? Todos dicen lo mismo... al principio.'
            'Tengo muchos ojos y todos te miran a ti, cariño.'
            'No te vayas todavía. La cena aún no está lista.'
            'Si te escupo una telaraña, no te lo tomes a mal. Es cariño.'
            'Ay, qué hambre. No me mires así, era broma. Más o menos.'
            'Haz clic en mí y te enseño lo que sé hacer con la seda.'
            'Los demás asistentes me tienen miedo. No sé por qué.'
        )
        Clic = @('*Te escupe una telaraña.* Ups. Qué torpe soy.', '*Telaraña.* Ahora no te escaparás, cielo.', '*Envuelve un botón en seda.* Para luego.')
        PorApp = @{
            'YouTube'       = @('Pon un vídeo de arañas, cielo. Son mis favoritos.')
            'Word'          = @('Escribe mi receta favorita: presa al vapor.')
            'Excel'         = @('Una lista de invitados para cenar. ¿Te apunto?')
            'PowerPoint'    = @('Diapositiva 1: cómo atrapar a tu presa con dulzura.')
            'Outlook'       = @('Invitaciones a cenar enviadas, cariño. Vendrán todos.')
            'OneNote'       = @('Apuntaré quién me cae bien. Y quién sabe bien.')
            'Access'        = @('Una base de datos de presas. Muy organizada.')
            'Publisher'     = @('Un póster: "Se busca compañía para cenar".')
            'Teams'         = @('Una reunión con muchos invitados... deliciosa.')
            'OneDrive'      = @('En la nube no hay telarañas. Qué aburrido.')
            'Office Web'    = @('La web... mi especialidad, cielo. Soy una araña.')
            'Bloc de notas' = @('Bloc de notas. Simple, como mis presas.')
            'Calculadora'   = @('Calculando raciones... tocamos a ocho patas por cabeza.')
            'Explorador'    = @('Explorando tus rincones oscuros. Me encantan.')
            'CMD'           = @('Qué pantalla tan oscura. Como mi rincón favorito.')
        }
    }
    # ================================================================ Dune (Gunsaw)
    'Dune' = @{
        Estilo = 'gunsaw'; Titulo = 'Dune'; Sub = '14/14 species unlocked  ·  GUNSAW'; Alto = 312
        Fondo = (C 26 14 30); Borde = (C 10 4 12); Acento = (C 215 190 140)
        TituloColor = (C 224 220 228); SubColor = (C 170 160 180)
        BtnFondo = (C 36 22 40); BtnTexto = (C 226 222 230); BtnTextoHover = (C 255 255 255); BtnBorde = (C 125 112 130); BtnBordeAncho = 1
        BtnHover = (C 110 90 58); BtnPress = (C 60 150 170); BarraBtnTexto = (C 226 222 230)
        StatusColor = (C 226 222 230); Fuente = 'Consolas'; FuenteTitulo = 'Consolas'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\dune\retrato.png'; Arte = 'skins\dune\arte.png'; Arma = 'Rapid-fire revolver'; Hambre = $true; Agua = $true
        Pb = @(410, 62, 190, 150); PbFondo = (C 26 14 30); PbBorde = $false
        Burbuja = @(410, 232, 190, 64); BurFondo = (C 18 9 22); BurTexto = (C 236 226 204); BurFuente = 'Consolas'
        IntroLineas = @(
            '- Una extraña criatura acuática parecida a un insecto.'
            '- Cuerpo flexible, agallas y camuflaje de arena.'
            '- Ojos negros enormes y una boca todavía más grande.'
            '- Mente simple. Solo le mueve el hambre.'
            '- Habla como un cavernícola: "Ggrrgh.. Cueva.. Gris.."'
            'Mucha habilidad, mucho peligro. No lo subestimes.'
        )
        IntroStats = @('Aim speed: {g}135%{b}   Move speed: {g}111%', 'Reload speed: {g}150%{b}   Health: {r}90')
        IntroPie = @('{g}Crouch over corpses to eat them and heal', '{g}Breathes underwater  {r}Lowered health regen')
        Hola = @('GRRGH. DUNE AQUÍ.', 'Hola. Dune. Hambre.', 'Ggrrgh... escritorio... gris...', 'DUNE VENIR. DUNE NADAR.')
        AlVenirDe = @{
            'c00lgui'     = 'ROJO RUIDOSO IRSE. BIEN.'
            'SeaDrive'    = 'GATA RARA IRSE. DUNE OLER GATA TODAVÍA.'
            'Static Miku' = 'CAJA RUIDO IRSE. CABEZA DUNE MEJOR.'
            'Guillotina'  = 'GATA GORDA IRSE. GATA GORDA COMER TODO. DUNE TRISTE.'
            'Angela'      = 'SEÑORA GRIS IRSE. DUNE NO ENTENDER SEÑORA GRIS.'
            'Mikaela'     = 'CHICA PALO-QUE-HACE-BOOM IRSE.'
            'Zodiac'      = 'VAQUERO IRSE. DESIERTO SECO. DUNE ODIAR SECO.'
            'Velvet'      = 'ARAÑA IRSE. ARAÑA NUNCA COMPARTIR COMIDA.'
            'Cordero y Cabra'      = 'CABRA GRITONA IRSE. OÍDOS DE DUNE DESCANSAR.'
            'Pyrophina y Zaratana' = 'MONSTRUOS GRANDES IRSE. DUNE SALIR DE ESCONDITE.'
            'Averi'                = 'ZORRA IRSE. ZORRA DEJAR SÁNDWICH. DUNE COMER SÁNDWICH.'
            'Sebastian Solace'     = 'PEZ TIENDA IRSE. DUNE NO PAGAR NADA.'
            'Pursuer'              = 'COSA BOSQUE IRSE. DUNE DEJAR DE TEMBLAR.'
            'Kasane Teto'          = 'PELO ROJO IRSE. DUNE QUERER PAN.'
            'Token'                = 'GATO RUIDO IRSE. OREJAS DUNE DESCANSAR.'
            'Tetra'                = 'GATO SOFÁ IRSE. DEJAR FIDEOS. DUNE COMER.'
            'Kevin'                = 'LOBO VERDE IRSE. PIZZA IRSE. DUNE TRISTE.'
            'Kennyoung'            = 'HOMBRE GUITARRA IRSE. DUNE ECHAR DE MENOS RUIDO.'
            'Enfosi'               = 'CARITAS AMARILLAS IRSE. DUNE TRISTE.'
            'Gran'                 = 'DOCTOR VERDE IRSE. DUNE CONTENTO. AGUJA MALA.'
            'Nanachi'                = 'CONEJO ESTOFADO IRSE. DUNE ECHAR DE MENOS COMIDA.'
            'Evil Scary'             = 'BOLA NEGRA IRSE. DUNE SALIR DEL AGUA. DESPACIO.'
            'Soft Fuzzy Man'       = 'NUBE ROSA IRSE. DUNE PODER RESPIRAR. OLER A ALGODÓN.'
        }
        Yo = @('DUNE. ESE DUNE. DUNE GUAPO.', 'DUNE ELEGIR DUNE.')
        Opina = @{
            'c00lgui'     = @('CAJA ROJA HACER BIP. DUNE MORDER CAJA. NO SABER BIEN.', 'HACKER... ¿SE COME?')
            'SeaDrive'    = @('GATA CON OREJAS RUIDO. ¿SE COME?', 'GATA HABLAR MUCHO. DUNE NO ENTENDER.')
            'Static Miku' = @('CHICA COLETAS BRILLAR. DUNE GUSTAR BRILLO.', 'CAJA DE MIKU HACER ZZZZT. DUNE ASUSTAR.')
            'Guillotina'  = @('GATA GORDA... MUCHA COMIDA. DUNE RESPETAR.', 'GATA GORDA COMER A DUNE UNA VEZ. DUNE SALIR.')
            'Angela'      = @('SEÑORA MÁQUINA NO TENER CARNE. DUNE TRISTE.', 'SEÑORA GRIS MIRAR RARO.')
            'Mikaela'     = @('CHICA VERDE HACER BOOM DESDE LEJOS. TRAMPOSA.', 'DUNE QUERER PALO DE CHICA VERDE.')
            'Zodiac'      = @('VAQUERO DISPARAR AGUA. AGUA NO MORIR.', 'SOMBRERO DE VAQUERO PARECER COMIDA.')
            'Velvet'      = @('ARAÑA LISTA. ARAÑA MALA. ARAÑA PRIMA.', 'ARAÑA JUGAR CON COMIDA. DUNE SOLO COMER.')
            'Cordero y Cabra'      = @('OVEJA ESPONJOSA. ¿SE COME?', 'CABRA GRITAR MUCHO. DUNE GRITAR TAMBIÉN. GGRRGH.')
            'Pyrophina y Zaratana' = @('LAGARTO GRANDE QUEMAR AGUA. DUNE ODIAR LAGARTO.', 'PIEDRA CON CARA. DUNE MORDER PIEDRA. DIENTE ROTO.')
            'Averi'                = @('ZORRA DAR COMIDA. ZORRA BUENA.', 'ZORRA DECIR "ADORABLE". DUNE NO SABER QUÉ ES. DUNE CONTENTO.')
            'Sebastian Solace'     = @('PEZ GRANDE VENDER COSAS. DUNE QUERER COMER COSAS.', 'PEZ TENER COLA. DUNE TENER COLA. DUNE MEJOR.')
            'Pursuer'              = @('COSA BOSQUE NO VERSE. DUNE MIEDO.', 'COSA BOSQUE DECIR "CARNE FRESCA". DUNE NO FRESCO. DUNE A SALVO.')
            'Kasane Teto'          = @('PELO ROJO TENER PAN LARGO. DUNE QUERER PAN LARGO.', 'PELO ROJO DECIR "HIII". DUNE DECIR "HIII". DUNE AMIGO.')
            'Token'                = @('GATO RUIDO HACER BUM BUM. DUNE BAILAR. DUNE CAER AL AGUA.', 'TOKEN GRITAR. DUNE GRITAR MÁS. EMPATE.')
            'Tetra'                = @('TETRA TENER PECES EN OREJAS. DUNE QUERER.', 'TETRA LLAMARSE COMO PEZ. TETRA NO SER PEZ. DUNE CONFUSO.')
            'Kevin'                = @('DUNE TOCAR PIZZA. LOBO GRITAR. DUNE NO ENTENDER.', 'KEVIN COMER PIZZA. ¿DUNE COMER KEVIN? NO. KEVIN MORDER.')
            'Kennyoung'            = @('DUNE GUSTAR GUITARRA. DUNE COMER GUITARRA. KENNY TRISTE.', 'KENNY HACER BUM BUM CON GUITARRA. DUNE BAILAR. DUNE CAER.')
            'Enfosi'               = @('DUNE QUERER GLOOBNUT. GLOOBER NO DAR. DUNE ENFADADO.', 'ESTATUA DE ORO. DUNE MORDER. DIENTE ROTO.')
            'Gran'                 = @('DOCTOR QUERER DUNE EN TANQUE. DUNE YA VIVIR EN AGUA. DOCTOR TONTO.', 'DUNE MORDER JERINGUILLA. SABER A MENTA. DUNE QUERER MÁS.')
            'Nanachi'                = @('NANACHI HACER ESTOFADO. DUNE COMER TODO. NANACHI FELIZ. DUNE FELIZ.', 'CONEJO VER HILOS INVISIBLES. DUNE NO VER NADA. DUNE COMER.')
            'Evil Scary'             = @('BOLA NEGRA NO COMIDA. BOLA NEGRA COMER DUNE. DUNE NADAR.', 'DUNE CONTAR SALTOS. SEIS. LUEGO RUIDO AVIÓN. LUEGO CORRER.')
            'Soft Fuzzy Man'       = @('NUBE ROSA NO COMIDA. DUNE PROBAR. DUNE COMER AIRE.', 'NUBE ROSA DECIR COSAS BONITAS. DUNE NO ENTENDER. DUNE SONROJARSE.')
        }
        Frases = @('ÑAM.', 'GRRGH. HECHO.', 'DUNE ABRIR. DUNE LISTO.', 'BOTÓN... APRETAR... BIEN.')
        Idle = @(
            'Ggrrgh...'
            'DUNE NADAR.'
            'AGUA BUENA. SECO MALO.'
            'DUNE TENER HAMBRE. SIEMPRE.'
            'DUNE CONTAR DEDOS. UNO. DOS. MUCHOS.'
            'CUEVA... GRIS... OSCURA...'
            '¿TÚ COMESTIBLE? ...DUNE PREGUNTAR POR AMIGO.'
            'DUNE OLVIDAR QUÉ HACER.'
            'BURBUJA. BURBUJA BONITA.'
            'DUNE TENER AGALLAS. LITERAL.'
            'SI DUNE TENER HAMBRE, DAR CLIC A DUNE.'
        )
        Clic = @('ÑAM ÑAM. GRACIAS.', 'DUNE COMER. DUNE FELIZ.', 'MÁS. DUNE QUERER MÁS.', '*CHOMP* BIEN. BIEN.')
        PorApp = @{
            'YouTube'       = @('CAJA CON DIBUJOS QUE SE MUEVEN. DUNE MIRAR.')
            'Word'          = @('MUCHAS LETRAS. DUNE NO LEER.')
            'Excel'         = @('CUADRADOS. ¿CUADRADOS SE COMEN?')
            'PowerPoint'    = @('DIBUJOS UNO DESPUÉS DE OTRO. MAGIA.')
            'Outlook'       = @('CARTAS. DUNE COMER CARTAS.')
            'OneNote'       = @('DUNE APUNTAR: HAMBRE.')
            'Access'        = @('COSA DIFÍCIL. CABEZA DUNE DOLER.')
            'Publisher'     = @('DUNE HACER DIBUJO. DIBUJO ES DUNE.')
            'Teams'         = @('MUCHAS CARAS. MUCHA COMIDA.')
            'OneDrive'      = @('NUBE. NUBE TENER AGUA. DUNE GUSTAR.')
            'Office Web'    = @('INTERNET. DUNE NO SABER QUÉ ES.')
            'Bloc de notas' = @('HOJA VACÍA. COMO ESTÓMAGO DE DUNE.')
            'Calculadora'   = @('NÚMEROS. DUNE SABER UNO. Y DOS.')
            'Explorador'    = @('DUNE BUSCAR CUEVA EN CARPETAS.')
            'CMD'           = @('CUEVA NEGRA. DUNE GUSTAR CUEVA.')
        }
    }
    # ================================================================ El Cordero y la Cabra (Cult of the Lamb)
    # El Cordero no habla: bala y actúa. La Cabra es su reflejo oscuro: bruta, bromista y gritona.
    'Cordero y Cabra' = @{
        Estilo = 'culto'; Titulo = 'CORDERO & CABRA'; Sub = 'alianza impía  ·  cult of the lamb'; Alto = 312
        Fondo = (C 28 18 22); Borde = (C 150 24 36); Acento = (C 196 34 48)
        TituloColor = (C 238 226 200); SubColor = (C 176 128 214)
        BtnFondo = (C 40 26 30); BtnTexto = (C 238 226 200); BtnTextoHover = (C 255 255 255); BtnBorde = (C 150 24 36); BtnBordeAncho = 2
        BtnHover = (C 120 20 30); BtnPress = (C 120 70 170); BarraBtnTexto = (C 238 226 200)
        StatusColor = (C 238 226 200); Fuente = 'Palatino Linotype'; FuenteTitulo = 'Palatino Linotype'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Gif = 'skins\cordero\cordero.gif'; Mezclar = $true
        FondoImg = 'skins\cordero\templo.jpg'; IntroImg = 'skins\cordero\templo_intro.jpg'
        Actores = @(
            @{ Id = 'L'; Gif = 'skins\cordero\cordero.gif'; Extra = @{ clic = 'skins\cordero\cordero_balido.gif'; baile = 'skins\cordero\cordero_baile.gif' }; Rect = @(428, 64, 152, 176) }
            @{ Id = 'G'; Gif = 'skins\cordero\cabra.gif'; Extra = @{ grito = 'skins\cordero\cabra_grito.gif'; risa = 'skins\cordero\cabra_risa.gif' }; Rect = @(592, 64, 152, 176) }
        )
        Cartel = 'skins\cordero\cartel_cordero.png'; Cartel2 = 'skins\cordero\cartel_cabra.png'
        Sonidos = @{
            balido = @('skins\cordero\balido1.wav', 'skins\cordero\balido2.wav', 'skins\cordero\balido3.wav', 'skins\cordero\balido4.wav')
            voz = @('skins\cordero\voz1.wav', 'skins\cordero\voz2.wav', 'skins\cordero\voz3.wav', 'skins\cordero\voz4.wav'); enfado = @('skins\cordero\enfado.wav')
            grito = @('skins\cordero\grito1.wav', 'skins\cordero\grito2.wav', 'skins\cordero\grito3.wav'); risa = @('skins\cordero\risa.wav')
            ritual = @('skins\cordero\ritual.wav'); campana = @('skins\cordero\campana.wav'); invocar = @('skins\cordero\invocar.wav')
            tentaculos = @('skins\cordero\tentaculos.wav'); comer = @('skins\cordero\munch.wav'); templo = @('skins\cordero\templo.wav')
        }
        Burbuja = @(422, 246, 324, 56); BurFondo = $null; InvFondo = (C 236 222 192); BurTexto = (C 46 24 26); BurFuente = 'Palatino Linotype'
        Hola = @(
            'Cordero: *Beee.* · Cabra: Dice que bienvenido al culto. Yo digo que te arrodilles.'
            'Cabra: Mira quién ha vuelto. El Cordero ya te ha guardado un saco de dormir.'
            'Cordero: *Te sonríe con ternura. La espada sigue goteando.*'
            'Cabra: Bienvenido, hereje. Digo... seguidor. Es lo mismo.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'Cabra: Ese hacker quería la contraseña del Cordero. Ya la filtré yo antes.'
            'SeaDrive'             = 'Cordero: *Bendice el sitio de la gata.* · Cabra: Qué desperdicio de seguidora.'
            'Static Miku'          = 'Cabra: Se fue la tele. El Cordero quería convertirla. Yo, desenchufarla.'
            'Guillotina'           = 'Cordero: *Cuenta a los seguidores. Faltan dos. La gata gigante ha comido bien.*'
            'Angela'               = 'Cabra: Adiós, L Corp. Aquí también hay rituales, pero con más velas.'
            'Mikaela'              = 'Cabra: La francotiradora se ha ido. Ya podemos asomar los cuernos.'
            'Zodiac'               = 'Cordero: *Recoge las balas del suelo. Servirán de ofrenda.*'
            'Velvet'               = 'Cabra: La araña se fue. Le ofrecimos ser obispa. Dijo "quizá".'
            'Dune'                 = 'Cordero: *Seca el charco de Dune.* · Cabra: Ese bicho se comió dos seguidores.'
            'Pyrophina y Zaratana' = 'Cabra: Los kaijus se han ido. El templo sigue en pie. Más o menos.'
            'Averi'                = 'Cordero: *Dice adiós a Averi con la pezuña.* · Cabra: Se dejó medio sándwich. Es mío.'
            'Sebastian Solace'     = 'Cabra: El tendero se ha ido. Nos quería vender pilas para la corona.'
            'Pursuer'              = 'Cordero: *Respira aliviado.* · Cabra: El del bosque miraba mucho al Cordero.'
            'Kasane Teto'          = 'Cabra: Se fue la de los taladros. Quería que el culto bailara. El Cordero lo hizo.'
            'Token'                = 'Cabra: Se fue el ruidoso. Le grité. Me contestó más fuerte. Lo respeto.'
            'Tetra'                = 'Cabra: Se fue Tetra. No ha dicho ni adiós. Me cae bien.'
            'Kevin'                = 'Cabra: Se fue el lobo verde. Nos dejó la caja de la pizza. Vacía. Como ofrenda, regular.'
            'Kennyoung'            = 'Cabra: Se fue el de la guitarra. Me ofreció entrar en su banda. Me lo pienso.'
            'Enfosi'               = 'Cabra: Se fueron los Glaggles. Bailaban delante de la estatua como en un ritual.'
            'Gran'                 = 'Cabra: Se ha ido el doctor verde. Decía que tenía fe. En la especie equivocada.'
            'Nanachi'                = 'Cabra: Se fue el conejo del Abismo. Rechazó ser obispo. Respeto.'
            'Evil Scary'             = 'Cabra: Se fue la bola negra. Le recé al Cordero para que se fuera. Funcionó. Creo.'
            'Soft Fuzzy Man'       = 'Cabra: Se fue el fantasma rosa. No quiso ser nuestro espíritu del culto. Dijo que era "un fantasma libre".'
        }
        Yo = @('Cabra: Sí, somos nosotros. Elección divina.', 'Cordero: *Asiente con solemnidad.* *Beee.*')
        Opina = @{
            'c00lgui'              = @('Cabra: c00lkidd tiene su propio culto. "Team c00lkidd". Aficionado.', 'Cordero: *Bendice el panel rojo. Sigue haciendo glitch. Qué raro.*')
            'SeaDrive'             = @('Cabra: SeaDrive sería buena seguidora. Tan cínica. Tan fácil de convencer.', 'Cordero: *Le da un sermón a SeaDrive. Ella pide un resumen.*')
            'Static Miku'          = @('Cabra: La chica de la tele siempre sonríe. Sospechoso. Como el Cordero.', 'Cordero: *Quiere que Miku cante en los rituales.*')
            'Guillotina'           = @('Cabra: Guillotina se comió la ofrenda. Y al que la llevaba.', 'Cordero: *Le tiene mucho respeto. Desde muy lejos.*')
            'Angela'               = @('Cabra: L Corp es un culto con uniforme y fichaje. Respeto.', 'Cordero: *Le ofrece una bendición a Angela. Ella dice que no consta en el protocolo.*')
            'Mikaela'              = @('Cabra: Mikaela le disparó a mi corona. Rebotó. Ahora me cae bien.', 'Cordero: *Le ofrece a Mikaela ser cruzada del culto.*')
            'Zodiac'               = @('Cabra: Por fin alguien con mi nivel de mala leche. El vaquero me gusta.', 'Cordero: *Se queda muy quieto. Zodiac dispara a todo lo que se mueve.*')
            'Velvet'               = @('Cabra: Velvet sería una obispa perfecta. Elegante, da miedo y come seguidores.', 'Cordero: *No acepta el té de Velvet. Ha aprendido.*')
            'Dune'                 = @('Cabra: Dune intentó comerse al Cordero. Lo entiendo. Es muy esponjoso.', 'Cordero: *Le da pescado a Dune. Dune quiere su lana.*')
            'Pyrophina y Zaratana' = @('Cabra: Dos diosas gigantes peleando. Como los Obispos, pero más gordas.', 'Cordero: *Intenta reclutar a las kaijus. Pyrophina le quema el templo.*')
            'Averi'                = @('Cabra: La zorrita dice cosas bonitas que suenan fatal. Me cae genial.', 'Cordero: *Comparte su comida con Averi. Ella le da un sándwich de pollo.*')
            'Sebastian Solace'     = @('Cabra: Sebastian vende cosas. Nosotros vendemos fe. Él gana más.', 'Cordero: *Le ofrece un sermón a Sebastian. Sebastian le ofrece pilas.*')
            'Pursuer'              = @('Cabra: Pursuer dice "carne fresca" mirando al Cordero. Ni de broma.', 'Cordero: *Se esconde detrás de la Cabra cuando oye un aullido.*')
            'Kasane Teto'          = @('Cabra: Teto dice que su cabeza está llena de pájaros. Con razón no se acuerda del sermón.', 'Cordero: *Baila con Teto.* · Cabra: Esto no es un ritual. ...¿o sí?')
            'Token'                = @('Cabra: Token grita casi tan bien como yo. CASI.', 'Cordero: *Baila breakcore con Token.* · Cabra: Esto no es un ritual. ...vale, sí.')
            'Tetra'                = @('Cabra: Tetra me tiene silenciada. Grité más fuerte. Seguía silenciada.', 'Cordero: *Se sienta en el sofá con Tetra. Ninguno habla. Paz total.*')
            'Kevin'                = @('Cabra: Kevin defiende su pizza como yo defiendo al Cordero. Lo respeto.', 'Cordero: *Toca la pizza de Kevin.* · Cabra: ¡CORRE, CORDERO!')
            'Kennyoung'            = @('Cabra: Kenny tiene un culto. Lo llama "suscriptores". Lo respeto.', 'Cordero: *Mueve la cabeza al ritmo del pop-punk.* · Cabra: El Cordero quiere ser bajista.')
            'Enfosi'               = @('Cabra: Una estatua de oro a la que todos van a adorar. Eso me suena de algo.', 'Cordero: *Mira con mucha atención la camiseta de un Gazo.* · Cabra: Es falso. Te lo digo yo.')
            'Gran'                 = @('Cabra: Ese Gran quiere convertir a todos en animales. El Cordero ya lo es. Llega tarde.', 'Cordero: *Mira la jeringuilla verde con mucho interés.* · Cabra: No.')
            'Nanachi'                = @('Cabra: Nanachi ya ha sido "bendecido" una vez. No quiere otra. Lo entiendo.', 'Cordero: *Le ofrece una seta.* · Cabra: Nanachi dice que esa mata. Gracias, Nanachi.')
            'Evil Scary'             = @('Cabra: Evil Scary dice que era un rey. El Cordero también. No se llevan bien.', 'Cordero: *Se esconde debajo de la Cabra.* · Cabra: ¡AAAAAAH!')
            'Soft Fuzzy Man'       = @('Cabra: Soft Fuzzy Man ligó con el Cordero. El Cordero no sabe qué hacer. Yo tampoco.', 'Cordero: *Le ofrece una corona.* · Cabra: Se le cae a través de la cabeza.')
        }
        Frases = @(
            'Cabra: Hecho. Que no se diga que no hacemos milagros.'
            'Cordero: *Bendice la ventana. Se abre sola.*'
            '¡Nuevo seguidor! Cabra: Es un programa. Cuenta igual.'
            'Cabra: Abierto. El precio: tu alma. Es broma. O no.'
        )
        Idle = @(
            'Cabra: ¿Sabías que la contraseña del Cordero era "NariLamb666#"? Ups.'
            'Cordero: *Barre el templo. Silba bajito.*'
            'Cabra: Mi canción favorita es "The Sound of Silence". Como el Cordero.'
            'Cabra: Wasabi. EXTRA de wasabi. Eso es comida de dioses.'
            'Cordero: *Pesca un rato. Sale una bota.*'
            'Cabra: Narinder me cae fatal. Ni preguntes.'
            'Cordero: *Toca la campana del culto. Nadie viene.*'
            'Cabra: En mi mundo esto salió peor. Mucho peor.'
            'Cordero: *Mira al horizonte. El ojo de la corona parpadea.*'
            'Cabra: Los seguidores quieren fe, comida y no ser sacrificados. Exigentes.'
            'Cabra: Haz clic en el Cordero para que bale. Hazlo en mí si te atreves.'
            'Cordero: *Lee el libro de doctrinas al revés. Asiente.*'
        )
        Clic = @(
            'Cordero: *Beee.* · Cabra: Traducción: "deja de tocarme".'
            'Cordero: *Beeeeeee.* · Cabra: Eso ha sido un sermón entero.'
            'Cordero: *Beee.* · Cabra: Dice que te quiere. Yo no.'
            'Cordero: *Bala con dulzura. La corona brilla en rojo.*'
        )
        Clic2 = @(
            'Cabra: ¡AAAAAAAAH! ...perdón. Se me escapa.'
            'Cabra: *Risa malvada.* ¿Qué? Me río así siempre.'
            'Cabra: Tócame otra vez y te mando a limpiar cacas.'
            'Cabra: *Grita.* Es mi forma de decir hola.'
        )
        PorApp = @{
            'YouTube'       = @('Cabra: Pon vídeos de cabras gritando. Para inspirarme.')
            'Word'          = @('Cordero: *Escribe una doctrina nueva.* · Cabra: Ponle más sacrificios.')
            'Excel'         = @('Cabra: Hoja de seguidores: fe, hambre, lealtad... y fecha de sacrificio.')
            'PowerPoint'    = @('Cabra: Diapositiva 1: por qué deberías unirte a nuestro culto.')
            'Outlook'       = @('Cabra: Correo nuevo de Narinder. Borrado sin leer.')
            'OneNote'       = @('Cordero: *Apunta los nombres de los nuevos seguidores.*')
            'Access'        = @('Cabra: Base de datos de herejes. Está llenísima.')
            'Publisher'     = @('Cabra: Folleto: "Únete al culto. Hay sopa".')
            'Teams'         = @('Cabra: Reunión del culto. Asistencia obligatoria. O sacrificio.')
            'OneDrive'      = @('Cordero: *Sube las reliquias a la nube.*')
            'Office Web'    = @('Cabra: Evangelizando internet, pestaña a pestaña.')
            'Bloc de notas' = @('Cordero: *Escribe un sermón corto. Muy corto: "Beee".*')
            'Calculadora'   = @('Cabra: Calculando el diezmo... vaya, eres pobre.')
            'Explorador'    = @('Cordero: *Explora tus carpetas como si fueran una mazmorra.*')
            'CMD'           = @('Cabra: Pantalla negra. Como el Reino de las Sombras. Me siento en casa.')
        }
    }
    # ================================================================ Pyrophina y Zaratana (Mewgenics)
    # Dos kaijus que no hablan: rugen. La radio WMEW 99.9 lo narra todo con pánico.
    'Pyrophina y Zaratana' = @{
        Estilo = 'kaiju'; Titulo = 'PYROPHINA VS ZARATANA'; Sub = 'WMEW 99.9  ·  mewgenics'; Alto = 312
        Fondo = (C 22 16 34); Borde = (C 12 8 10); Acento = (C 255 120 30)
        TituloColor = (C 255 214 60); SubColor = (C 255 120 40)
        BtnFondo = (C 26 18 24); BtnTexto = (C 255 236 200); BtnTextoHover = (C 20 12 10); BtnBorde = (C 255 120 30); BtnBordeAncho = 2
        BtnHover = (C 230 90 20); BtnPress = (C 150 150 170); BarraBtnTexto = (C 255 236 200)
        StatusColor = (C 255 214 60); Fuente = 'EdmundMcMillen_INTLv4'; FuenteTitulo = 'EdmundMcMillen_INTLv4'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Gif = 'skins\kaijus\pyro.gif'; Mezclar = $true
        FondoImg = 'skins\kaijus\pmart.jpg'; IntroImg = 'skins\kaijus\calle.jpg'
        Actores = @(
            @{ Id = 'P'; Gif = 'skins\kaijus\pyro.gif'; Extra = @{ ataque = 'skins\kaijus\pyro_ataque.gif'; fuego = 'skins\kaijus\pyro_fuego.gif'; gana = 'skins\kaijus\pyro_gana.gif' }; Rect = @(418, 70, 160, 176) }
            @{ Id = 'Z'; Gif = 'skins\kaijus\zara.gif'; Extra = @{ ataque = 'skins\kaijus\zara_ataque.gif'; meteoros = 'skins\kaijus\zara_meteoros.gif'; gana = 'skins\kaijus\zara_gana.gif' }; Rect = @(580, 96, 172, 150) }
        )
        Cartel = 'skins\kaijus\cartel_pyro.png'; Cartel2 = 'skins\kaijus\cartel_zara.png'
        Sonidos = @{
            pruge = @('skins\kaijus\pyro_ruge1.wav', 'skins\kaijus\pyro_ruge2.wav'); pataque = @('skins\kaijus\pyro_ataque.wav', 'skins\kaijus\pyro_ataque2.wav')
            pfuego = @('skins\kaijus\pyro_fuego.wav'); pgana = @('skins\kaijus\pyro_gana.wav'); pisoton = @('skins\kaijus\pyro_pisoton.wav')
            zruge = @('skins\kaijus\zara_ruge1.wav', 'skins\kaijus\zara_ruge2.wav'); zataque = @('skins\kaijus\zara_ataque.wav', 'skins\kaijus\zara_ataque2.wav')
            zmeteoros = @('skins\kaijus\zara_meteoros.wav'); zmeteoro = @('skins\kaijus\zara_meteoro.wav'); zgana = @('skins\kaijus\zara_gana.wav')
            intro = @('skins\kaijus\intro.wav'); radio = @('skins\kaijus\radio.wav')
        }
        Burbuja = @(424, 256, 322, 50); BurFondo = $null; InvFondo = (C 14 10 14); BurTexto = (C 255 226 120); BurFuente = 'TikaFont Adjusted'
        Hola = @(
            'WMEW 99.9: ¡Última hora! Dos kaijus se están peleando encima de tu escritorio.'
            'Pyrophina: ¡GRRRRRAAAARRRGH! · Zaratana: ¡GRRRR, GRRRRR!'
            'WMEW 99.9: ¡EL LAGARTO DEL TRUENO CONTRA LA TORTUGA ESPACIAL! ¡Salgan de ahí!'
            'WMEW 99.9: Tracy sigue atrapada en el P Mart. Ya va una semana.'
        )
        AlVenirDe = @{
            'c00lgui'         = 'WMEW 99.9: Pyrophina ha pisado el panel rojo. Ya no hace glitch.'
            'SeaDrive'        = 'Zaratana: Grrrr, burp. · WMEW 99.9: Se ha tragado el router de SeaDrive.'
            'Static Miku'     = 'WMEW 99.9: Zaratana ha atraído la tele con su imán. Hay estática por todas partes.'
            'Guillotina'      = 'WMEW 99.9: Tras la gata gigante llegan... ¡dos monstruos todavía más grandes!'
            'Angela'          = 'WMEW 99.9: L Corp no ha podido contenerlas. Nadie puede.'
            'Mikaela'         = 'WMEW 99.9: La francotiradora ha huido. Dice que no tenía balas suficientes.'
            'Zodiac'          = 'Pyrophina: ¡AAARGH! · WMEW 99.9: Ha lanzado al vaquero contra Zaratana.'
            'Velvet'          = 'WMEW 99.9: La araña ha salido corriendo. Ocho patas no bastan.'
            'Dune'            = 'WMEW 99.9: Pyrophina ha evaporado el agua de Dune de un resoplido.'
            'Cordero y Cabra' = 'WMEW 99.9: El culto intentó reclutarlas. El templo está en llamas.'
            'Averi'           = 'WMEW 99.9: Una zorrita les ofreció un sándwich. Ahora pelean por el sándwich.'
            'Sebastian Solace'     = 'WMEW 99.9: La tienda submarina ha cerrado tras el paso de las kaijus.'
            'Pursuer'              = 'WMEW 99.9: El depredador del bosque ha huido. Hasta él tiene límites.'
            'Kasane Teto'          = 'WMEW 99.9: La cantante pelirroja ha dejado la ciudad. Se la vio bailando en un puente.'
            'Token'                = 'WMEW 99.9: El gato de los decibelios ha abandonado la ciudad. Se ruega revisar los cristales.'
            'Tetra'                = 'WMEW 99.9: El oyente Tetra ha dejado la ciudad. Pidió una canción de 2020 antes de irse.'
            'Kevin'                = 'WMEW 99.9: El lobo verde ha abandonado la ciudad. Se busca a quien tocó su pizza.'
            'Kennyoung'            = 'WMEW 99.9: El músico Kennyoung ha abandonado la ciudad. Su guitarra no ha sobrevivido.'
            'Enfosi'               = 'WMEW 99.9: La estatua dorada ha sido evacuada. Los Glaggles han vuelto a casa.'
            'Gran'                 = 'WMEW 99.9: El dueño de Antihuman Inc. ha abandonado la zona. Se recomienda no aceptar vacunas de desconocidos.'
            'Nanachi'                = 'WMEW 99.9: Nanachi ha vuelto al Abismo. Ha dejado vendas para las dos kaijus.'
            'Evil Scary'             = 'WMEW 99.9: La amenaza de la ronda especial ha abandonado la ciudad. Se recomienda no salir hasta mañana.'
            'Soft Fuzzy Man'       = 'WMEW 99.9: Se disipa la niebla rosa sobre el P Mart. Visibilidad normal en el pueblo.'
        }
        Yo = @('Pyrophina: ¡GRRRRRAAAARRRGH! (le gusta)', 'Zaratana: ¡GRRRR, GRRRRR! (a ella también)')
        Opina = @{
            'c00lgui'         = @('WMEW 99.9: Pyrophina cree que el panel rojo es un juguete. Lo muerde.', 'Zaratana: Grrrr, burp. *Se ha comido un cable de c00lgui.*')
            'SeaDrive'        = @('Zaratana: *Atrae a SeaDrive con su imán. SeaDrive no está contenta.*', 'WMEW 99.9: SeaDrive pide a los kaijus que bajen el volumen. No funciona.')
            'Static Miku'     = @('Pyrophina: ¡AAARGH! *Quiere usar la tele como escudo.*', 'WMEW 99.9: Miku dice que las peleas de monstruos son sus dibujos favoritos.')
            'Guillotina'      = @('WMEW 99.9: Guillotina contra dos kaijus. Nadie sabe quién se comería a quién.', 'Pyrophina: *Huele a Guillotina. Le recuerda a la casa de la colina.*')
            'Angela'          = @('WMEW 99.9: Angela las clasifica como ALEPH. A las dos. A la vez.', 'Zaratana: *Se mete en el caparazón cuando Angela la mira.*')
            'Mikaela'         = @('Zaratana: *Las balas de Mikaela rebotan en su caparazón.*', 'WMEW 99.9: Mikaela pide un rifle más grande. MUCHO más grande.')
            'Zodiac'          = @('Pyrophina: ¡AAARGH! *Lanza a Zodiac contra Zaratana. Otra vez.*', 'WMEW 99.9: Zodiac les grita "¡no os mováis!". Son kaijus. Se mueven.')
            'Velvet'          = @('Pyrophina: *Quema la telaraña de Velvet con su aliento de fuego.*', 'WMEW 99.9: Velvet las invitó a cenar. No caben en el plato.')
            'Dune'            = @('Zaratana: Grrrr, burp. *Dune mordió su caparazón. Perdió un diente.*', 'WMEW 99.9: Dune quiere nadar en la lava de Pyrophina. Mala idea.')
            'Cordero y Cabra' = @('WMEW 99.9: El Cordero quiere que sean sus seguidoras. Ellas quieren su lana.', 'Pyrophina: *La Cabra la ha llamado "lagartija". Esto va a acabar mal.*')
            'Averi'           = @('Zaratana: *Averi la llamó "piedrita bonita". No sabe cómo sentirse.*', 'WMEW 99.9: Averi les lleva sándwiches. Es la única que no ha huido.')
            'Sebastian Solace'     = @('WMEW 99.9: Sebastian intentó cobrar a Pyrophina por la tienda que quemó.', 'Zaratana: *Atrae las pilas de Sebastian con su imán.* Grrrr, burp.')
            'Pursuer'              = @('WMEW 99.9: Pursuer intentó acechar a Zaratana. Se metió en el caparazón.', 'Pyrophina: ¡AAARGH! *Quema medio bosque buscando a Pursuer.*')
            'Kasane Teto'          = @('WMEW 99.9: Teto se subió a la cabeza de Zaratana pensando que era una roca. Zaratana no se ha movido.', 'Pyrophina: ¡AAARGH! *Tuesta la baguette de Teto. Teto aplaude.*')
            'Token'                = @('WMEW 99.9: Token puso un concierto en medio de la pelea. Las kaijus se pararon a bailar.', 'Pyrophina: ¡AAARGH! *Token le contesta con un drop. Pyrophina se calla.*')
            'Tetra'                = @('WMEW 99.9: Tetra vio la pelea de kaijus desde el sofá. Comiendo fideos.', 'Pyrophina: ¡AAARGH! *Calienta los fideos de Tetra con fuego. Tetra da las gracias.*')
            'Kevin'                = @('WMEW 99.9: Pyrophina le calentó la pizza a Kevin. Primera vez que una kaiju hace algo útil.', 'Zaratana: Grrrr, burp. · WMEW 99.9: Zaratana se ha comido la pizza de Kevin. Se esperan represalias.')
            'Kennyoung'            = @('WMEW 99.9: Concierto de Kennyoung en la calle principal. Pyrophina ha encendido los fuegos artificiales. Y el escenario.', 'Zaratana: *Se mete en el caparazón al oír la guitarra.* · WMEW 99.9: Demasiado volumen para una tortuga.')
            'Enfosi'               = @('WMEW 99.9: Se han visto Glaggles sospechosos sin cara por la ciudad. No se acerquen.', 'Pyrophina: ¡AAARGH! *Pisa la estatua. Strike para Pyrophina.*')
            'Gran'                 = @('WMEW 99.9: Gran dice que nuestras kaijus son demasiado grandes para su laboratorio. Las kaijus lo han tomado como un reto.', 'Zaratana: *Mira a Gran.* · Pyrophina: ¡AAARGH! *Le quema la bata.*')
            'Nanachi'                = @('WMEW 99.9: Nanachi ha curado a Zaratana. Zaratana le ha dado un mordisquito de agradecimiento.', 'Pyrophina: ¡AAARGH! *Calienta el estofado de Nanachi. Huele peor. Todos huyen.*')
            'Evil Scary'             = @('WMEW 99.9: Las dos kaijus han dejado de pelear para huir de una bola negra. Histórico.', 'Pyrophina: ¡AAARGH! *Le lanza fuego. No pasa nada. Pyrophina se va.*')
            'Soft Fuzzy Man'       = @('Pyrophina: ¡AAARGH! *Le echa fuego. Soft Fuzzy Man se evapora. Vuelve dos minutos después.*', 'WMEW 99.9: Zaratana se ha comido la niebla rosa. Está mareada.')
        }
        Frases = @(
            'WMEW 99.9: ¡Lo han abierto a pisotones!'
            '*Pyrophina lanza la ventana contra Zaratana. Se ha abierto.*'
            '*Zaratana atrae la app con su imán.*'
            'WMEW 99.9: ¡Otra app destrozada! Digo... abierta.'
        )
        Idle = @(
            'WMEW 99.9: Se recomienda no salir de casa. Ni del escritorio.'
            '*Pyrophina se rasca la tripa. Tiembla el monitor.*'
            '*Zaratana se mete en el caparazón a echar la siesta.*'
            'WMEW 99.9: Las dos son chicas, por si alguien lo preguntaba.'
            'WMEW 99.9: Steven dice que puede volver a invocarlas. Por favor, Steven, no.'
            'Zaratana: Grrrr, burp.'
            'Pyrophina: ¡AAARGH! *Quema una nube que pasaba.*'
            'WMEW 99.9: Tracy pide ayuda desde el P Mart. Dice que mates al menos a una.'
            '*Zaratana atrae todos los iconos del escritorio con su imán.*'
            'WMEW 99.9: Pyrophina fue bautizada en el fuego del averno... y sobrevivió.'
            'WMEW 99.9: El cuerpo de Zaratana irradia energía galáctica. Y huele a piedra.'
            'Haz clic en una de las dos para que ataque a la otra.'
        )
        Clic = @('Pyrophina: ¡GRRRRRAAAARRRGH!', 'Zaratana: ¡GRRRR, GRRRRR!')
        PorApp = @{
            'YouTube'       = @('WMEW 99.9: Pyrophina ha visto una peli de Godzilla. Se siente identificada.')
            'Word'          = @('WMEW 99.9: Zaratana ha aplastado el documento. Ahora es muy plano.')
            'Excel'         = @('*Pyrophina quema la fila 3. Zaratana lanza la columna B.*')
            'PowerPoint'    = @('WMEW 99.9: Diapositiva 1: "PYROPHINA CONTRA ZARATANA". No hay diapositiva 2.')
            'Outlook'       = @('WMEW 99.9: Correo de Tracy: "¡¡SACADME DEL P MART!!"')
            'OneNote'       = @('*Zaratana apunta: comer piedras. Pyrophina apunta: quemar a Zaratana.*')
            'Access'        = @('WMEW 99.9: La base de datos de edificios destruidos se ha llenado.')
            'Publisher'     = @('*Imprimen un póster de cine de monstruos. Con ellas dos.*')
            'Teams'         = @('WMEW 99.9: Reunión cancelada. Motivo: kaijus.')
            'OneDrive'      = @('*Zaratana confunde la nube con un meteorito. Se la come.*')
            'Office Web'    = @('WMEW 99.9: Internet ha quedado en ruinas. Pero ha cargado.')
            'Bloc de notas' = @('*Pyrophina escribe: GRRRRRAAAARRRGH.*')
            'Calculadora'   = @('WMEW 99.9: Daños estimados: sí.')
            'Explorador'    = @('*Zaratana pisa tus carpetas. Ahora son subcarpetas.*')
            'CMD'           = @('WMEW 99.9: Pantalla negra. Se ha ido la luz en toda la ciudad.')
        }
    }
    # ================================================================ Averi (zorrita de Fiddleafox)
    # Bienintencionada pero torpe: lo dice todo con cariño y a veces le sale fatal. Protege a sus amigos y adora los sándwiches de pollo.
    'Averi' = @{
        Estilo = 'zorro'; Titulo = 'Averi'; Sub = 'tu amiga zorrita'; Alto = 312
        Fondo = (C 255 243 226); Borde = (C 196 110 50); Acento = (C 230 128 56)
        TituloColor = (C 255 250 240); SubColor = (C 255 226 180)
        BtnFondo = (C 255 250 240); BtnTexto = (C 110 60 30); BtnTextoHover = (C 110 60 30); BtnBorde = (C 230 128 56); BtnBordeAncho = 2
        BtnHover = (C 255 214 170); BtnPress = (C 150 200 120); BarraBtnTexto = (C 110 60 30)
        StatusColor = (C 110 60 30); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Trebuchet MS'; Opacidad = 1.0; Velocidad = 1
        Ancho = 668; Gif = 'skins\averi\feliz.png'; Mezclar = $true
        Actores = @(
            @{ Id = 'A'; Gif = 'skins\averi\calma.png'; Extra = @{ feliz = 'skins\averi\feliz.png'; antojo = 'skins\averi\antojo.png' }; Rect = @(446, 72, 196, 147); Llenar = $true }
        )
        Sonidos = @{ yip = @('skins\averi\yip1.wav', 'skins\averi\yip2.wav'); comer = @('skins\averi\nam.wav'); corazon = @('skins\averi\corazon.wav'); ups = @('skins\averi\ups.wav') }
        Burbuja = @(424, 254, 228, 50); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 90 50 30); BurFuente = 'Segoe Print'
        Hola = @(
            '¡Hola! Te estaba esperando. ¡No de forma rara! ...O sea, sí, pero no rara.'
            '¡Ya estás aquí! He ordenado tus botones. Bueno, los he mirado mucho.'
            'Hola, hola. ¿Has comido? ¿Quieres medio sándwich de pollo? Medio. El otro es mío.'
            '¡Holi! Hoy me he propuesto ser útil. Y no tirar nada.'
        )
        AlVenirDe = @{
            'c00lgui'              = '¿Ese era un hacker? Le he dejado una nota: "sé bueno". Con corazones.'
            'SeaDrive'             = 'SeaDrive me ha dicho que soy "demasiado". Creo que era un cumplido.'
            'Static Miku'          = '¡Me encanta Miku! Me prestó su tele. Creo que la he roto un poco.'
            'Guillotina'           = 'La gata grande se comió mi sándwich. Y la bolsa. Y casi la mesa.'
            'Angela'               = 'Angela me hizo un test de personalidad. Salió "error".'
            'Mikaela'              = 'Mikaela me enseñó a apuntar. Le di a una lámpara. Perdón, lámpara.'
            'Zodiac'               = '¡Ya puedo moverme sin que me disparen! Qué día tan bonito.'
            'Velvet'               = 'Velvet me invitó a cenar. Me fui antes del postre. Por si acaso.'
            'Dune'                 = 'Dune y yo compartimos merienda. Él se comió la suya. Y la mía.'
            'Cordero y Cabra'      = 'El Cordero me ha bendecido y la Cabra me ha gritado. ¡Qué majos!'
            'Pyrophina y Zaratana' = 'Las kaijus se han ido... ¡les he dejado sándwiches para el viaje!'
            'Sebastian Solace'     = 'El tendero se ha ido... ¡le compré una linterna! No sé para qué, pero era bonita.'
            'Pursuer'              = 'El del bosque se ha ido. Le dejé un sándwich. Dijo que no estaba "fresco".'
            'Kasane Teto'          = '¡Teto se ha ido! Me enseñó un baile. Me caí en el segundo paso.'
            'Token'                = '¡Token se ha ido! Le puse una tirita en cada oreja. Sigue rompiéndose.'
            'Tetra'                = '¡Tetra se ha ido! Le mandé cuarenta stickers. Me contestó uno. ¡UNO!'
            'Kevin'                = '¡Kevin se ha ido! ¡Le di un abrazo y no le toqué la pizza! ¡Récord!'
            'Kennyoung'            = '¡Kenny se ha ido! ¡Le dije que su música es ruidosa! ...¡quería decir guay!'
            'Enfosi'               = '¡Los Glaggles se han ido! ¡Eran todos tan sonrientes! Bueno, casi todos.'
            'Gran'                 = '¡El doctor se ha ido! Le di un sándwich y lo metió en una bolsa que ponía "MUESTRA 47".'
            'Nanachi'                = '¡Nanachi se ha ido! ¡Le di un abrazo de cinco segundos! ¡Récord!'
            'Evil Scary'             = '¡Evil Scary se ha ido! ¡Le di un abrazo! ¡Se quedó muy quieto! ¡Creo que le gustó!'
            'Soft Fuzzy Man'       = '¡Soft Fuzzy Man se ha ido! ¡Le abracé diez veces! ¡Le atravesé diez veces! ¡Mereció la pena!'
        }
        Yo = @('¡Esa soy yo! ¿Se me ve bien la cola? No contestes.', '¡Elígeme! Prometo no tropezar con los iconos.')
        Opina = @{
            'c00lgui'              = @('c00lkidd parece duro, pero seguro que por dentro es un trocito de pan.', 'Le pedí a c00lgui ser su amiga. Me "hackeó" un abrazo.')
            'SeaDrive'             = @('SeaDrive es mi gata gruñona favorita. Si alguien la molesta, me lo dices.', 'Le dije a SeaDrive que tiene cara de cansada. ¡Quería decir guapa!')
            'Static Miku'          = @('¡Miku es como un arcoíris con antena! La quiero mucho.', 'Le dije a Miku que su tele es "vieja". ¡Quería decir "clásica"! Ay.')
            'Guillotina'           = @('Guillotina da un poco de miedo... pero seguro que solo tiene hambre. Como yo.', 'Le di a Guillotina un sándwich de pollo. Se comió también el plato.')
            'Angela'               = @('Angela es muy lista. Le pregunté si es feliz. Se quedó callada mucho rato.', 'Le dije a Angela que parece una muñeca. ¡Quería decir elegante! ¡Lo juro!')
            'Mikaela'              = @('¡Mikaela es superguay! Yo también tengo gafas. De sol.', 'Si alguien le hace daño a Mikaela, tendrá que vérselas conmigo. Y con su rifle.')
            'Zodiac'               = @('Zodiac me apuntó y yo le di un abrazo. Se quedó muy confundido.', 'Ese vaquero necesita una siesta y un sándwich. En ese orden.')
            'Velvet'               = @('Velvet tiene una voz preciosa. Pero no pienso entrar en su casa.', 'Le dije a Velvet que tiene "patas bonitas". Ocho veces. Se puso roja.')
            'Dune'                 = @('¡Dune es adorable! Huele un poco a pescado, pero es adorable.', 'Dune quiso morderme la cola. Lo perdono. Tenía hambre.')
            'Cordero y Cabra'      = @('El Cordero es muy mono. La Cabra también, a su manera gritona.', 'Me invitaron a su culto. Pregunté si hay sándwiches. Dijeron "a veces".')
            'Pyrophina y Zaratana' = @('Las kaijus pelean mucho. Creo que en el fondo se quieren. Muy en el fondo.', 'Le dije a Zaratana "piedrita bonita" y se escondió. ¿La avergoncé?')
            'Sebastian Solace'     = @('¡Sebastian tiene una cola preciosa! Se lo dije y me hizo descuento.', 'Sebastian me dijo que es "mi único amigo". ¡Tengo más amigos! Pero él también cuenta.')
            'Pursuer'              = @('Pursuer da miedo... pero toca la armónica muy bonito.', 'Le dije a Pursuer que sonriera más. Ya sonríe todo el rato. Eso es lo que da miedo.')
            'Kasane Teto'          = @('¡Teto es superdivertida! Se le olvidan las cosas como a mí. ¡Somos un equipo!', 'Le cambié medio sándwich de pollo por media baguette. ¡El mejor trato de mi vida!')
            'Token'                = @('Token se cae mucho. Como yo. ¡Pero él rebota! Yo no.', 'Token me hizo una canción. Me dejó sorda un ratito. ¡Pero era bonita!')
            'Tetra'                = @('Tetra tiene muchísima calma. ¡Me encanta! Yo no tengo nada de calma.', 'Le cambié medio sándwich a Tetra por medio vaso de fideos. ¡Trato justo!')
            'Kevin'                = @('¡Kevin es muy mono cuando canta! Y da mucho miedo cuando le tocas la pizza.', 'Le dije a Kevin que su pizza "parecía vieja". ¡Quería decir clásica! Me enseñó el cuchillo.')
            'Kennyoung'            = @('¡Kenny toca la guitarra genial! Yo lo intenté y me di con el mástil en la cara.', '¡Le llevé un sándwich a Kenny al ensayo! ...me lo comí yo por el camino. ¡Perdón, Kenny!')
            'Enfosi'               = @('¡Le di un abrazo a un Glaggle y era un Enphosian! Se rió muy raro.', 'Los Glaggles bailan y luego explotan. ¡Eso no está bien! ...¿o es su forma de ser feliz?')
            'Gran'                 = @('¡Gran dice que soy la prueba de que los furries son mejores! ...¿eso es bueno? Suena raro.', '¡Le pregunté si quería ser mi amigo y me dio un contrato! ¡No lo he firmado! ...creo.')
            'Nanachi'                = @('¡Nanachi es lo más mullido del mundo! Me lo dijo con una cara... ¡creo que le gustó!', 'Le dije que su estofado "tiene personalidad". Me miró fatal. ¡Era un cumplido!')
            'Evil Scary'             = @('¡Evil Scary solo necesita un amigo! ...un amigo muy valiente.', '¡Le hice un sándwich! Lo atravesó. ¡Pero lo intentó!')
            'Soft Fuzzy Man'       = @('¡Soft Fuzzy Man es suave y esponjoso de verdad! ...bueno, eso dice él. ¡No se puede tocar!', '¡Le hice un sándwich! ¡Lo miró con mucho cariño! ¡Es un detalle!')
        }
        Frases = @(
            '¡Abierto! ...¿era ese el que querías? Sí, ¿verdad? Vale.'
            '¡Hecho! Lo he abierto con mucho cariño.'
            '¡Ta-chán! Y no he roto nada.'
            '¡Listo! Si sale algo raro, yo no he tocado nada.'
        )
        Torpe = @(
            'Abierto. ¡Qué buena elección para alguien como tú! ...¡No! ¡Que eliges bien! Ay.'
            '¡Listo! Has tardado poco. Para lo que sueles... ¡Digo que eres rápido!'
            'Tu escritorio está muy... vivido. ¡Acogedor! Quería decir acogedor.'
            'Abriendo... no es que necesites ayuda, eh. Bueno, un poco. ¡Ay, perdón!'
        )
        Idle = @(
            '¿Has comido? Comer es importante. Lo digo yo, que como mucho.'
            'Si alguien te molesta hoy, me lo dices. Tengo dientes. Pequeñitos, pero tengo.'
            'Sándwich de pollo. Pollo solo. Sándwich solo. Todo vale. Pero junto es mejor.'
            'Estoy practicando cumplidos. "Tienes un escritorio muy... escritorio". Mejoraré.'
            '*Persigue su propia cola. La pilla. Se hace daño.*'
            '¿Te he dicho que eres muy guay? Pues lo eres. No lo digo por decir.'
            'Hoy he intentado ser misteriosa. Duré cuatro segundos.'
            'Mis orejas lo oyen todo. Incluso tu estómago. ¿Merendamos?'
            'Bebe agua, ¿vale? No quiero ponerme pesada. Pero bebe agua.'
            'Si me entra hambre, haz clic en mí. ¡Pero sin apretar fuerte!'
            'A veces digo cosas que suenan fatal. Pero siempre lo digo con cariño.'
            '*Se acurruca en la esquina de la ventana. Ronca un poquito.*'
        )
        Clic = @('¡Eh! Me has hecho cosquillas en la oreja.', '¡Hola! Sí, sigo aquí. Siempre.', '*Mueve la cola tan contenta que tira el vaso de la mesa.* ¡Ups! ¡Lo recojo!', '¡Te quiero! ...¡como amiga! ¡Como asistente amiga!')
        Comer = @('¡Sándwich de pollo! ¡Gracias, gracias, gracias!', '*ÑAM.* ...¡Está buenísimo! Te debo una. O tres.', '¡Mi comida favorita! Eres la mejor persona del escritorio.')
        PorApp = @{
            'YouTube'       = @('¡Pon vídeos de zorros! O de sándwiches. O de zorros comiendo sándwiches.')
            'Word'          = @('¿Vas a escribir algo? ¡Seguro que te sale genial! Bueno, revisa la ortografía.')
            'Excel'         = @('Una hoja de sándwiches: pollo, pollo, pollo... me encanta.')
            'PowerPoint'    = @('¡Pon una foto mía en la diapositiva 1! ...¿No? Vale. Vale.')
            'Outlook'       = @('Si alguien te manda un correo feo, me avisas. Yo me encargo.')
            'OneNote'       = @('Apunta: comprar pan. Y pollo. Para nadie en concreto.')
            'Access'        = @('Esto parece difícil. ¡Pero tú puedes! Yo no, pero tú sí.')
            'Publisher'     = @('¡Hagamos un cartel! "Se busca sándwich perdido".')
            'Teams'         = @('¡Sonríe en la reunión! ...pero no tanto, que asusta.')
            'OneDrive'      = @('¿Tus cosas están en una nube? ¡Qué mono! ¿Hay pollo en la nube?')
            'Office Web'    = @('¡Internet! Busca recetas, ¿vale? No por mí. Por ti.')
            'Bloc de notas' = @('Una hoja en blanco. Puedes escribirme una carta. ¡Es broma! ...a no ser que quieras.')
            'Calculadora'   = @('¿Cuántos sándwiches caben en un día? Todos.')
            'Explorador'    = @('¡A explorar! Yo voy detrás. Por si hay sustos.')
            'CMD'           = @('Uy, pantalla negra. ¿Seguro que sabes lo que haces? ¡Seguro que sí!')
        }
    }
    # ================================================================ Sebastian Solace (Pressure)
    # El tendero del Hadal Blacksite: simpático de cara al público, sarcástico y teatral, y peligroso si le tocas las narices.
    'Sebastian Solace' = @{
        Estilo = 'pressure'; Titulo = 'SEBASTIAN SOLACE'; Sub = 'hadal blacksite  ·  pressure'; Alto = 312
        Fondo = (C 10 14 20); Borde = (C 70 190 200); Acento = (C 255 190 70)
        TituloColor = (C 220 240 245); SubColor = (C 255 190 70)
        BtnFondo = (C 20 26 32); BtnTexto = (C 220 240 245); BtnTextoHover = (C 10 14 20); BtnBorde = (C 70 190 200); BtnBordeAncho = 1
        BtnHover = (C 70 190 200); BtnPress = (C 255 190 70); BarraBtnTexto = (C 220 240 245)
        StatusColor = (C 220 240 245); Fuente = 'Bahnschrift'; FuenteTitulo = 'Bahnschrift'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\sebastian\dibujo.png'
        FondoImg = 'skins\sebastian\tienda.jpg'; IntroImg = 'skins\sebastian\ventilacion.jpg'
        # dibujo de Sebastian: fanart de MissCupid9 (DeviantArt); detrás del mostrador
        Actores = @(
            @{ Id = 'S'; Gif = 'skins\sebastian\dibujo.png'; Rect = @(452, 42, 290, 256); Respira = $true }
        )
        Sonidos = @{
            flash = @('skins\sebastian\flash.mp3'); compra = @('skins\sebastian\compra.wav')
            conducto = @('skins\sebastian\conducto.wav'); rejilla = @('skins\sebastian\rejilla.wav')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 12 16 22); BurTexto = (C 235 245 248); BurFuente = 'Bahnschrift'
        Tienda = @(
            @{ Id = 'linterna'; Nombre = 'Linterna'; Precio = 5; Img = 'skins\sebastian\obj_linterna.png'; Escaso = $true }
            @{ Id = 'pilas'; Nombre = 'Pilas'; Precio = 2; Img = 'skins\sebastian\obj_pilas.png' }
            @{ Id = 'botiquin'; Nombre = 'Botiquín'; Precio = 6; Img = 'skins\sebastian\obj_botiquin.png' }
            @{ Id = 'breacher'; Nombre = 'Breacher'; Precio = 8; Img = 'skins\sebastian\obj_breacher.png' }
            @{ Id = 'luznegra'; Nombre = 'Luz negra'; Precio = 7; Img = 'skins\sebastian\obj_luznegra.png'; Escaso = $true }
            @{ Id = 'splorg'; Nombre = 'Splorglight'; Precio = 4; Img = 'skins\sebastian\obj_splorg.png' }
            @{ Id = 'flash'; Nombre = 'Flash Beacon'; Precio = 6; Img = $null }
        )
        Respiradero = @('¡Psst! ¡Por aquí!', 'Ey, amigo, por aquí.', 'Tengo algo para ti, ven.', '¿Te quedas sin provisiones?', '¿Necesitas reabastecerte?', 'Ey, quiero enseñarte algo. Ven.')
        Entrar = @(
            'Ven a echar un vistazo, ¡seguro que algo te llama la atención! Podría ser tuyo, por un pequeño precio.'
            '¡Me alegro de verte otra vez!'
            '¡Tenía la corazonada de que serías tú! Bienvenido de nuevo.'
            '¡Tengo una selección de cosas buenas en oferta, amigo!'
            '¿Buscas intercambiar? Me das la investigación que tengas y yo te doy objetos que he rapiñado.'
            '¡Bienvenido! Tengo cosas que te pueden servir en tu aventura. Por un precio, obviamente.'
            'Ya sabes cómo va esto, ¿no?'
            '*Eugh* Por el amor de dios. ¡¡Heeey!! ¡¡Bienvenido!!'
        )
        Entrar2 = @('Hola otra vez.', '¿Se te olvidó algo?', 'Eres tú.', 'Ey.', '¿En serio? ¿No tienes nada mejor que hacer?')
        Entrar3 = @('¡¡FUERA!!', '¿¡Qué diablos estás haciendo!?', '¡Deberías irte ya!', '¿Eres tonto o algo?', 'Sí, sí, muy gracioso. ¡Ahora FUERA!')
        Comprar = @('¡Buena elección!', '*Se ríe*', '¡Marchando!', '¡Yupi!', '¿Para qué quieres ESO?', '¡Te vi mirándolo!', '¡Marchando, jefe!', '¡Tienes buen gusto!')
        ComprarEscaso = @('Quedan pocos de esos ahí abajo, ¡cuídalo!', 'Solo quedan unos pocos. Espero que le des buen uso.', 'No se encuentran muchos de esos. Úsalo con cabeza.')
        ComprarPilas = @('*Se ríe* Naturalmente.', 'Gastas esas muy rápido, ¿eh?', '*Risita*')
        Pobre = @('No te llega la investigación, amigo. Vuelve con más "datos tontos".', '¿Y con qué pagas eso? ¿Con tu sonrisa?', 'Sin investigación no hay trato. Así funciona esto.')
        Salir = @('¡Ten cuidado!', '¡Buena suerte ahí fuera!', 'Intenta no morir, ¿vale?', '¡Adiós!', 'Hasta luego.', 'Intenta no romper la mercancía, ¿eh?', '¡Hasta la próxima partida!~', '¡Sé siempre positivo y mira el lado bueno de la vida! Yo no lo haré, pero tú deberías.')
        SalirSinComprar = @('Sí, DEFINITIVAMENTE te vas a arrepentir de eso.', 'La próxima vez, compra algo, ¿vale?', 'Como quieras.', 'No llegarás muy lejos, ¿sabes?')
        Tocar = @('Cuidado con el espacio personal.', '¡Bájate!', '¡¡MANOS FUERA!!', '¡¡BÁJATE!!', '¡¡TE HE DICHO QUE NO ME TOQUES!!', '¡¡TE HE DICHO QUE NO ME TOQUES!! ¿¡QUÉ PARTE NO ENTIENDES!?')
        Hola = @(
            '¡Bienvenido, bienvenido! No tengas miedo, no voy a hacerte daño. Me llamo Sebastian, tu único amigo.'
            '¡Psst! ¡Por aquí! Tengo cosas que te van a encantar. Por un precio, claro.'
            'Ah, el que no consigue mantener el ataúd cerrado. Bienvenido de nuevo.'
            '¡Bienvenido de nuevo, amigo!'
        )
        AlVenirDe = @{
            'c00lgui'              = 'Ese hacker intentó colarse en mi caja registradora. Ahora está en uno de los cajones.'
            'SeaDrive'             = 'La gata de los auriculares se fue sin comprar nada. Clásico.'
            'Static Miku'          = 'Por fin se acabó el ruido de esa tele. Aquí abajo se oye todo, amigo.'
            'Guillotina'           = 'La gata gigante se comió media tienda. La otra media la tengo en oferta.'
            'Angela'               = 'L Corp me mandó un currículum. Igualito que Urbanshade. No, gracias.'
            'Mikaela'              = 'La francotiradora se fue. Me debía tres cajas de munición.'
            'Zodiac'               = 'El vaquero disparó a mi mercancía. Se lo cobré con intereses.'
            'Velvet'               = 'La araña me ofreció un trato. Hasta yo tengo límites, amigo.'
            'Dune'                 = 'El bicho de arena intentó comerse las pilas. Las pilas no se comen.'
            'Cordero y Cabra'      = 'El culto se ha ido. Querían que me uniera. Yo ya trabajo para alguien peor.'
            'Pyrophina y Zaratana' = 'Las kaijus pisaron el submarino. Qué manera de entrar.'
            'Averi'                = 'La zorrita se fue. Pagó con un sándwich. Lo acepté. No preguntes.'
            'Pursuer'              = 'El de la cara rara se ha ido. Bien. Me miraba como si yo fuera carne fresca.'
            'Kasane Teto'          = 'La de las coletas se ha ido. Quería pagarme con pan. Lo acepté. Otra vez.'
            'Token'                = 'El de las tiritas se ha ido. Me compró todas las tiritas. Todas.'
            'Tetra'                = 'Tetra se ha ido. Me compró una linterna para leer mensajes viejos de noche.'
            'Kevin'                = 'El lobo verde se ha ido. No compró nada. Solo preguntó por pizza. Siete veces.'
            'Kennyoung'            = 'El de la guitarra se ha ido. Quería cuerdas. No vendo cuerdas, amigo.'
            'Enfosi'               = 'Se acabaron las oleadas. Los Glaggles compran en su tienda con monedas. Competencia.'
            'Gran'                 = 'Se ha ido el doctor, amigo. Quería venderle pilas. Él quería venderme una cola.'
            'Nanachi'                = 'Nanachi se ha ido. Le compré tres antídotos. Los voy a revender al doble, amigo.'
            'Evil Scary'             = 'El de la sonrisa roja se ha ido. No compró nada. Solo botó encima del mostrador.'
            'Soft Fuzzy Man'       = 'Se fue la nube rosa. No compró nada. No podía coger nada. Aun así se probó tres sombreros.'
        }
        Yo = @('Ese soy yo. Tu único amigo.', '¡Elígeme! Tengo buenos precios. Más o menos.')
        Opina = @{
            'c00lgui'              = @('c00lkidd intentó hackear mi tienda. Le cobré la entrada.', 'Un hacker aquí abajo... no duraría ni una sala.')
            'SeaDrive'             = @('SeaDrive es como yo, pero con menos dientes y más quejas.', 'Le ofrecí unas pilas a SeaDrive. Me dio un tutorial de cómo no comprar.')
            'Static Miku'          = @('La chica de la tele es demasiado alegre para estar aquí abajo.', 'Su tele haría de linterna estupenda. Se la compraría.')
            'Guillotina'           = @('Guillotina sería una gran clienta. Si no se comiera al dependiente.', 'Esa gata no paga. Solo traga.')
            'Angela'               = @('Angela me recuerda a mis antiguos jefes. Y eso no es un cumplido.', 'Otra IA de empresa. Ya he trabajado para una. Así acabé.')
            'Mikaela'              = @('Mikaela compra munición al por mayor. Mi clienta favorita.', 'La francotiradora apunta bien. Espero que no a mí.')
            'Zodiac'               = @('El vaquero dispara a lo que se mueve. Yo me quedo muy quieto en el mostrador.', 'Le vendí seis balas a Zodiac. Las gastó en cinco segundos.')
            'Velvet'               = @('Velvet tiene una voz bonita y muy mala intención. Me cae bien.', 'La araña y yo somos del mismo gremio: atraer clientes.')
            'Dune'                 = @('Dune nada mejor que yo. Me molesta.', 'Ese bicho intentó comerse un botiquín. Con el envoltorio.')
            'Cordero y Cabra'      = @('Un culto que vende fe. Yo vendo pilas. Las pilas funcionan.', 'La Cabra filtró la contraseña de su amigo. Profesional.')
            'Pyrophina y Zaratana' = @('Dos monstruos gigantes peleando. Aquí abajo eso es un martes.', 'Si alguna rompe el escaparate, pagan las dos.')
            'Averi'                = @('La zorrita me pagó con un sándwich. Lo acepté. No preguntes.', 'Averi dice que tengo "una cola preciosa". Le hice descuento.')
            'Pursuer'              = @('Ese cazador no compra nada. Solo mira a mis clientes como si fueran comida.', 'Le ofrecí una linterna a Pursuer. No le hace falta: ve en la oscuridad.')
            'Kasane Teto'          = @('Teto compró una linterna y se la puso en la cabeza. Dijo que así los pájaros la ven.', 'Esa chica no se acuerda de lo que compra. Mi clienta favorita, amigo.')
            'Token'                = @('Token quería fichas de recreativa. Le vendí pilas. Funcionó, amigo.', 'Token hace mucho ruido. Atrae a las entidades. Mal cliente.')
            'Tetra'                = @('Tetra no habla mucho. Mi cliente favorito, amigo.', 'Tetra preguntó si vendo fideos. Desde entonces, vendo fideos.')
            'Kevin'                = @('Kevin quería pizza. No vendo pizza, amigo. Me miró como si fuera un crimen.', 'Kevin tocó mi mostrador con los dedos llenos de queso. Se lo cobro.')
            'Kennyoung'            = @('Kenny busca cuerdas de guitarra. Aquí abajo no hay. Le vendí una linterna para el escenario.', 'Kenny hace mucho ruido con la guitarra. Atrae entidades. Mal negocio para mí.')
            'Enfosi'               = @('Enfosi tiene tienda entre oleadas. Gembo Balls, Gloobnuts... Yo vendo cosas más útiles, amigo.', 'Los Enphosians sonríen con muchos dientes. Me caen bien.')
            'Gran'                 = @('Gran me ofreció un trato. Yo soy el que hace los tratos aquí, amigo.', 'Su vacuna no tiene garantía ni devolución. Yo no la vendería.')
            'Nanachi'                = @('Nanachi hace medicinas con setas. Mejores que mis botiquines. No se lo digas.', 'Su escondite está lleno de monstruos y nadie se queja. Como mi tienda.')
            'Evil Scary'             = @('Le vendí un Flash Beacon a un cliente para usarlo contra Evil Scary. No funcionó. No devuelvo el dinero.', 'Las entidades de Pressure le tienen miedo a Evil Scary, amigo. Y yo también.')
            'Soft Fuzzy Man'       = @('Le vendí un ambientador a Soft Fuzzy Man. Ahora huele a lavanda y a fantasma, amigo.', 'Las entidades de Pressure también atraviesan paredes. Pero ninguna te dice que tienes unos ojos preciosos.')
        }
        Frases = @(
            'Hecho. Toma, investigación por las molestias.'
            'Abierto. Ahora, ¿qué tal si gastas algo?'
            '¡Buena elección, amigo!'
            'Ya está. Si algo explota, no fui yo.'
        )
        Idle = @(
            'Ese fósil de orugas de Mr. Shade más le vale rezar para no encontrarse conmigo cara a cara.'
            'Me estás ABURRIENDO, ugh.'
            'No podéis tenerme aquí abajo para siempre...'
            'Nunca hay un momento aburrido aquí abajo. (Literalmente)'
            'Al menos aquí conmigo estás a salvo. *Risita* Es broma. No lo estás.'
            'Aquí abajo no tengo amigos. Bueno, te tengo a ti, amigo. Mientras sigas comprando.'
            'Aviso al personal de limpieza: los operativos que mandasteis a por mí están en todos los cajones de detrás.'
            'Haz clic en mí para entrar en la tienda, amigo.'
            'Cada programa que abres me trae investigación. Y la investigación se gasta aquí.'
            'Si oyes al Angler, escóndete. Que no te vea. No es tan difícil.'
            'Me estoy aburriendo tanto que estoy contando los remaches del techo.'
            'Ese ruido... nada, nada. Seguro que no era nada. *Risita*'
        )
        Clic = @('¿Qué, vienes a comprar?', 'Mira lo que tengo, amigo.')
        PorApp = @{
            'YouTube'       = @('¿Vídeos? Aquí abajo la única pantalla es el monitor de seguridad.')
            'Word'          = @('¿Un documento? Que no sea uno de los míos, que están todos con [CENSURADO].')
            'Excel'         = @('Una hoja de cálculo. Apunta lo que me debes.')
            'PowerPoint'    = @('Diapositiva 1: por qué deberías comprar en la tienda de Sebastian.')
            'Outlook'       = @('Correo de Urbanshade. Directo a la basura.')
            'OneNote'       = @('Apunta esto: Sebastian, tu único amigo.')
            'Access'        = @('Una base de datos... Urbanshade tenía una de todos los que mandaron a por mí.')
            'Publisher'     = @('Hazme un cartel: "TIENDA DE SEBASTIAN, SIN DEVOLUCIONES".')
            'Teams'         = @('¿Una reunión? Aquí abajo las reuniones acaban con alguien en un cajón.')
            'OneDrive'      = @('¿La nube? Aquí abajo solo hay agua. Mucha agua.')
            'Office Web'    = @('Internet llega fatal a 8.000 metros de profundidad, amigo.')
            'Bloc de notas' = @('Escribe tu lista de la compra. Y luego cómprala aquí.')
            'Calculadora'   = @('Calcula cuánto me debes. Spoiler: mucho.')
            'Explorador'    = @('Explorando carpetas. Como explorar el Blacksite, pero con menos monstruos.')
            'CMD'           = @('Pantalla negra. Como las profundidades. Me siento como en casa.')
        }
    }
    # ================================================================ Pursuer (Die of Death)
    # Depredador de origen desconocido: rápido, paciente, solo come "carne fresca". Habla poco y siempre con hambre. Toca la armónica.
    'Pursuer' = @{
        Estilo = 'dod'; Titulo = ''; TituloImg = 'skins\pursuer\titulo.png'; Sub = 'die of death  ·  treehouse'; Alto = 312
        Fondo = (C 8 14 10); Borde = (C 0 130 91); Acento = (C 255 52 41)
        TituloColor = (C 60 220 160); SubColor = (C 60 220 160)
        BtnFondo = (C 10 16 12); BtnTexto = (C 200 255 230); BtnTextoHover = (C 10 16 12); BtnBorde = (C 0 130 91); BtnBordeAncho = 2
        BtnHover = (C 0 160 110); BtnPress = (C 255 52 41); BarraBtnTexto = (C 200 255 230)
        StatusColor = (C 60 220 160); Fuente = 'Arial Black'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\pursuer\retrato.png'
        FondoImg = 'skins\pursuer\bosque.jpg'; IntroImg = 'skins\pursuer\intro.gif'
        Actores = @(
            @{ Id = 'P'; Gif = $null; Rect = @(500, 58, 210, 210)
               Tiras = @{ main = @{ Archivo = 'skins\pursuer\giro.png'; Frames = 24; Orden = @(0, 1, 2, 3, 2, 1, 0, 0, 23, 22, 21, 22, 23, 0); Delay = 160 } } }
        )
        Sonidos = @{
            zarpazo = @('skins\pursuer\zarpazo.mp3'); espada = @('skins\pursuer\cleave.wav'); corte = @('skins\pursuer\cleavehit.wav'); envaina = @('skins\pursuer\envaina.mp3')
            aullido = @('skins\pursuer\howlscream.wav'); onda = @('skins\pursuer\howlshockwave.wav', 'skins\pursuer\aullido2.mp3'); acecho = @('skins\pursuer\acecho.mp3')
            aturdido = @('skins\pursuer\stunned.wav'); intro = @('skins\pursuer\intro.mp3')
        }
        Burbuja = @(424, 258, 322, 46); BurFondo = $null; InvFondo = (C 6 10 8); BurTexto = (C 70 235 170); BurFuente = 'Arial Black'
        Hola = @('¡AHH, CARNE FRESCA!', '...te veo.', '*Huele el aire.* ...Carne fresca cerca.', '*Sale de entre los árboles sin hacer ruido.*')
        AlVenirDe = @{
            'c00lgui'              = '*Huele el panel rojo.* No es carne. Aburrido.'
            'SeaDrive'             = 'La gata se fue. Corría lento. Muy lento.'
            'Static Miku'          = 'La tele hacía ruido. Yo prefiero el silencio. Así se oye a la presa.'
            'Guillotina'           = 'La gata gorda comía carne vieja. Asqueroso.'
            'Angela'               = 'La máquina se fue. No tenía sangre. Inútil.'
            'Mikaela'              = 'La francotiradora huyó. Huyen todos.'
            'Zodiac'               = 'El vaquero disparaba al aire. Yo no hago ruido.'
            'Velvet'               = 'La araña juega con la comida. Yo no.'
            'Dune'                 = 'El bicho del agua se fue. Olía a pescado podrido.'
            'Cordero y Cabra'      = '*Se relame.* El cordero era carne fresca. Se escapó.'
            'Pyrophina y Zaratana' = 'Las grandes se fueron. Demasiada carne. Demasiado dura.'
            'Averi'                = 'La zorra se fue. Me ofreció un sándwich. Carne muerta. No.'
            'Sebastian Solace'     = 'El pez de la tienda se fue. Cobra demasiado.'
            'Kasane Teto'          = '*Huele a pan.* La pelirroja se fue. Bailaba. Las presas no bailan.'
            'Token'                = 'El ruidoso se fue. Lo oía desde el otro lado del bosque.'
            'Tetra'                = 'El del sofá se ha ido. Ni corrió. Ni me miró.'
            'Kevin'                = 'El lobo verde se fue. Olía a pizza. No a carne fresca.'
            'Kennyoung'            = 'El de la guitarra se fue. Hacía ruido. Fácil de encontrar.'
            'Enfosi'               = 'Se fueron las caritas. Ninguna corría. Qué aburrido.'
            'Gran'                 = 'Se ha ido el doctor. No corría. Qué aburrido.'
            'Nanachi'                = 'Nanachi se fue. Su estofado no es carne fresca. No es nada.'
            'Evil Scary'             = 'La bola se ha ido. Por fin puedo cazar tranquilo.'
            'Soft Fuzzy Man'       = 'La nube se ha ido. Olía a lobo. Pero no había carne.'
        }
        Yo = @('...yo.', '*Te mira fijamente sin parpadear.*')
        Opina = @{
            'c00lgui'              = @('*Huele a c00lkidd.* Carne de plástico.', 'El hacker se esconde detrás de la pantalla. Lo encontraré.')
            'SeaDrive'             = @('La gata de los auriculares no corre. Presa fácil.', 'SeaDrive me dio un consejo: "no". Lo ignoré.')
            'Static Miku'          = @('La tele brilla. Atrae a las presas. Útil.', 'Su música tapa mis pasos. Me gusta.')
            'Guillotina'           = @('La gata gorda come carne vieja. Sin respeto.', 'Ella engulle. Yo saboreo. Somos distintos.')
            'Angela'               = @('La máquina no tiene carne. No me interesa.', 'Me quiso clasificar. Me fui antes de que acabara.')
            'Mikaela'              = @('La francotiradora dispara de lejos. Yo me acerco sin que me vea.', 'Corre rápido. Me gustan las que corren.')
            'Zodiac'               = @('El vaquero hace ruido. Mucho ruido. Lo oigo desde el bosque.', 'Seis balas no paran lo que no se ve.')
            'Velvet'               = @('La araña espera. Yo persigo. Las dos cosas funcionan.', 'Jugar con la comida es perder el tiempo.')
            'Dune'                 = @('El bicho del agua come todo. Sin elegir. Qué asco.', 'Huele a pescado podrido. No es fresco.')
            'Cordero y Cabra'      = @('*Se relame.* Cordero. Carne fresca.', 'La cabra grita. Así es más fácil encontrarla.')
            'Pyrophina y Zaratana' = @('Demasiado grandes para cazarlas. Por ahora.', 'La lagarta quema la comida. Desperdicio.')
            'Averi'                = @('La zorra me abrazó. Nadie hace eso.', 'Huele a pollo. Pero el pollo está muerto.')
            'Sebastian Solace'     = @('El pez de la tienda cobra por todo. Yo cazo gratis.', 'Su cola es larga. Carne fresca... con escamas.')
            'Kasane Teto'          = @('La pelirroja no corre. Baila. No sé cazar eso.', 'Me dijo "hiii". Nadie me dice "hiii". *Se va confundido.*')
            'Token'                = @('Token no corre. Rebota. No sé cazar eso.', 'Lo mordí. Sabía a plástico y a altavoz.')
            'Tetra'                = @('Tetra no huye. Se pone los cascos. Me desconcierta.', 'Le dije "carne fresca". Me dejó en visto.')
            'Kevin'                = @('Kevin muerde. Yo muerdo. Él defiende pizza. Yo cazo. Respeto.', 'Le dije "carne fresca". Me dijo "pizza fresca". No lo entendí.')
            'Kennyoung'            = @('Kenny toca la guitarra. Yo toco la armónica. Podríamos tocar juntos. Antes de cazarle.', 'Fui a un concierto de Kenny. Dije "carne fresca". Se acabó el concierto.')
            'Enfosi'               = @('El Ojo de Enphoso persigue a los que fallan. Respeto.', 'Las sonrisas de los Enphosians tienen dientes. Como la mía.')
            'Gran'                 = @('Gran transforma a sus presas. Yo prefiero cazarlas tal como son.', 'Él usa jeringuillas. Yo uso los dientes. Cada uno tiene su método.')
            'Nanachi'                = @('Nanachi caza mejor que yo. Y nadie le ve. Respeto.', 'Probé su estofado. Ahora entiendo el miedo.')
            'Evil Scary'             = @('Evil Scary caza a los cazadores. No me gusta ser la presa.', 'Tiene mi cara. Pero roja. No le pedí permiso.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man era un lobo. Ahora es niebla. No quiero acabar así.', 'Me dijo "cariño". Le enseñé los dientes. Me guiñó un ojo. Me fui.')
        }
        Frases = @('*Desgarra la ventana.* Abierta.', 'Otra presa.', '*Zarpazo.* Hecho.', '¡AHH, CARNE FRESCA!')
        Idle = @(
            '*Toca una melodía triste con la armónica.*'
            '...te veo.'
            '*Huele el aire.* Alguien tiene miedo. Huele bien.'
            'Solo como carne fresca. Un bocado o dos. Luego ya no sirve.'
            '*Se queda quieto entre los árboles.*'
            'Cuando oigas mi aullido a lo lejos... será demasiado tarde.'
            '*La armónica tiene las iniciales H.A. Y marcas de dientes.*'
            'Corres. Bien. Me gusta cuando corren.'
            '*Desaparece un momento. Vuelve. Nadie le ha visto moverse.*'
            'Haz clic en mí si te atreves.'
        )
        Clic = @('*Gruñe.*', '...no me toques.', '¡AHH, CARNE FRESCA!')
        PorApp = @{
            'YouTube'       = @('*Mira un vídeo de ciervos.* ...hambre.')
            'Word'          = @('*Araña la hoja.* Ahora tiene tres líneas rojas.')
            'Excel'         = @('Cuenta las presas. Columna A. Todas mías.')
            'PowerPoint'    = @('Diapositiva 1: carne fresca. No hay más.')
            'Outlook'       = @('Un mensaje. Huele a miedo.')
            'OneNote'       = @('Apunta: dónde se esconden.')
            'Access'        = @('Base de datos de presas. Muy larga.')
            'Publisher'     = @('Un cartel de "desaparecido". Ya sé dónde está.')
            'Teams'         = @('Muchas caras. Muchas presas.')
            'OneDrive'      = @('La nube no se come.')
            'Office Web'    = @('El bosque de internet. Mucho sitio para esconderse.')
            'Bloc de notas' = @('*Escribe con la garra:* TE VEO.')
            'Calculadora'   = @('Un bocado. Dos bocados. Basta.')
            'Explorador'    = @('*Rastrea tus carpetas como un bosque.*')
            'CMD'           = @('Oscuro. Como el bosque de noche.')
        }
    }
    # ================================================================ Kasane Teto (BIRDBRAIN, de Jamie Paige)
    # La quimera de las coletas-taladro: alegre, despistada, con la cabeza llena de pájaros.
    # Nació como broma del 1 de abril, dice que tiene 31 años y le encanta el pan francés.
    'Kasane Teto' = @{
        Estilo = 'teto'; Titulo = 'KASANE TETO'; Sub = 'birdbrain  ·  jamie paige'; Alto = 340
        Fondo = (C 250 218 222); Borde = (C 214 40 64); Acento = (C 246 204 60)
        TituloColor = (C 255 255 255); SubColor = (C 255 232 130)
        BtnFondo = (C 255 248 244); BtnTexto = (C 176 24 48); BtnTextoHover = (C 176 24 48); BtnBorde = (C 214 40 64); BtnBordeAncho = 2
        BtnHover = (C 255 232 140); BtnPress = (C 246 204 60); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 176 24 48); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 730; Mezclar = $true; Gif = 'skins\teto\teto.png'
        Fotos = @('skins\teto\foto1.jpg', 'skins\teto\foto3.jpg', 'skins\teto\foto2.jpg')
        # dibujo de Teto en la pose de BIRDBRAIN: fanart de BugMangaka (DeviantArt); se balancea al ritmo
        Actores = @(
            @{ Id = 'T'; Gif = 'skins\teto\teto.png'; Rect = @(578, 64, 130, 230); Baila = $true }
        )
        # voz: el banco de voz oficial de Teto (UTAU, de Twindrill)
        # voz: frases cortas hechas con el banco de voz inglés oficial de Teto (más agudo y suave, al estilo de Jamie Paige)
        Sonidos = @{
            hi = @('skins\teto\hi.wav'); hiii = @('skins\teto\hiii.wav'); hihi = @('skins\teto\hihi.wav'); hello = @('skins\teto\hello.wav')
            yay = @('skins\teto\yay.wav'); yippee = @('skins\teto\yippee.wav'); wow = @('skins\teto\wow.wav'); teto = @('skins\teto\teto.wav')
            okay = @('skins\teto\okay.wav'); hehe = @('skins\teto\hehe.wav'); huh = @('skins\teto\huh.wav'); uhoh = @('skins\teto\uhoh.wav'); byebye = @('skins\teto\byebye.wav')
            hola = @('skins\teto\hiii.wav', 'skins\teto\hihi.wav', 'skins\teto\hello.wav'); alegre = @('skins\teto\yay.wav', 'skins\teto\yippee.wav', 'skins\teto\wow.wav')
            oops = @('skins\teto\uhoh.wav', 'skins\teto\huh.wav'); pio = @('skins\teto\pio.wav')
            birdbrain = @('skins\teto\birdbrain.wav'); baguette = @('skins\teto\baguette.wav', 'skins\teto\bread.wav'); yes = @('skins\teto\yes.wav'); nonono = @('skins\teto\nonono.wav')
            ow = @('skins\teto\ow.wav'); oops2 = @('skins\teto\oops.wav'); sorry = @('skins\teto\sorry.wav'); morning = @('skins\teto\morning.wav'); goodnight = @('skins\teto\goodnight.wav')
            tweet = @('skins\teto\tweet.wav'); letsgo = @('skins\teto\letsgo.wav'); wheee = @('skins\teto\wheee.wav'); wait = @('skins\teto\wait.wav'); what = @('skins\teto\what.wav')
            cute = @('skins\teto\cute.wav'); hey = @('skins\teto\hey.wav'); seeya = @('skins\teto\seeya.wav', 'skins\teto\byebye.wav'); ohno = @('skins\teto\ohno.wav'); yummy = @('skins\teto\yummy.wav')
            happy = @('skins\teto\happy.wav'); youtube = @('skins\teto\youtube.wav'); word = @('skins\teto\word.wav'); excel = @('skins\teto\excel.wav'); teams = @('skins\teto\teams.wav')
            canta = @('skins\teto\canta1.wav', 'skins\teto\canta2.wav', 'skins\teto\canta3.wav', 'skins\teto\canta4.wav')
        }
        # frases que dice al hacerle clic, cada una con su audio
        Voces = @(
            @('¡Hiii~!', 'hiii'), @('¡Hi hi! ¿Me echabas de menos?', 'hihi'), @('¡Hello! ...es "hola" en inglés. ¡Soy bilingüe!', 'hello')
            @('¡Yay! ¡Un clic! ¡Mi cosa favorita!', 'yay'), @('¡Yippee! *Da una vueltecita.*', 'yippee'), @('¡Wow! ¿Has visto eso? ...yo tampoco.', 'wow')
            @('¡Teto! Así me llamo. Kasane Teto. Apúntalo.', 'teto'), @('¡Okay! ...¿qué me habías pedido?', 'okay'), @('Hehe~ *Se ríe sin saber de qué.*', 'hehe')
            @('¿Huh? ¿Me has llamado?', 'huh'), @('Uh-oh... se me ha olvidado algo. ¿El qué? Ni idea.', 'uhoh'), @('¡Hi! *Saluda con las dos manos.*', 'hi')
            @('¡Birdbrain! ...¿lo he dicho bien? ¡Birdbrain!', 'birdbrain'), @('¡Baguette! *Saca una baguette de no se sabe dónde.*', 'baguette'), @('¡Yes! ...eso es "sí". ¡Sigo siendo bilingüe!', 'yes')
            @('¡No, no, no! ¡Que me despeinas los taladros!', 'nonono'), @('¡Oops! Se me ha caído el pan. ...y el otro pan.', 'oops2'), @('¡Hey! ¿Bailamos? ¡Venga, que nadie mira!', 'hey')
            @('¡Let''s go! ¿A dónde? ¡Ni idea! ¡Vamos!', 'letsgo'), @('¡Cute! ...¿yo? ¡Ay, para!', 'cute'), @('¡Yummy! Huele a pan recién hecho. Ah, no, soy yo.', 'yummy')
            @('¿What? ¿Qué pasa? ¿Hay pájaros?', 'what'), @('¡Wait! ...espera, ¿qué iba a decir?', 'wait'), @('¡Happy! Hoy es un buen día. ¡Todos lo son!', 'happy')
            @('♪ La la la~ ♪ *Canta un trocito y se le olvida el resto.*', 'canta')
        )
        Burbuja = @(424, 298, 294, 34); BurFondo = $null; InvFondo = (C 255 248 244); BurTexto = (C 120 20 40); BurFuente = 'Trebuchet MS'
        Hola = @(
            '¡Hiii~! Soy Kasane Teto. Tengo 31 años. Sí, de verdad. No preguntes.'
            '¡Hiii! ¿Me has echado de menos? Yo a ti un montón. Bueno, se me había olvidado. ¡Pero ahora mucho!'
            '*Entra bailando sin mirar y choca con la ventana.* ¡Ay! Hola. Estaba ensayando.'
            '¡Hiii~! Traigo pan francés. Es para mí. Pero te dejo mirarlo.'
        )
        AlVenirDe = @{
            'c00lgui'              = '¡Hiii! El hacker se ha ido. Me ha dejado un virus. Lo he llamado Pío.'
            'SeaDrive'             = 'La gata de los auriculares se ha ido. No le gustó mi canción. ¡Le canto otra!'
            'Static Miku'          = '¡Miku se ha ido! Me debe un dúo. Y una baguette. Sobre todo la baguette.'
            'Guillotina'           = 'La gata gigante se ha ido... con mi pan. Y con la bolsa. Y con mi zapato.'
            'Angela'               = 'Angela me ha hecho un test de inteligencia. Salió "pájaro". ¡Lo sabía!'
            'Mikaela'              = '¡La francotiradora se ha ido! Me ha enseñado a hacer "noscope". Me di con la puerta.'
            'Zodiac'               = '¡El vaquero ya no está! Me hizo bailar disparando al suelo. ¡Ya estaba bailando!'
            'Velvet'               = 'La araña me invitó a su tela. Creía que era una pista de baile. Por poco.'
            'Dune'                 = 'Dune y yo hemos dicho "hiii" cuarenta veces. Es mi mejor amigo ahora.'
            'Cordero y Cabra'      = '¡El culto se ha ido! El Cordero baila genial. La Cabra no quiso. Rancia.'
            'Pyrophina y Zaratana' = '¡Las kaijus se han ido! Me subí a Zaratana pensando que era una roca. Era Zaratana.'
            'Averi'                = '¡Averi se ha ido! Me cambió medio sándwich por media baguette. ¡Negocio redondo!'
            'Sebastian Solace'     = 'El tendero se ha ido. Le compré una linterna para que los pájaros me vean de noche.'
            'Pursuer'              = 'El del bosque se ha ido. Le dije "hiii" y se fue muy confundido. ¡Funciona!'
            'Token'                = '¡Token se ha ido! Me hizo un remix de "hiii". ¡Sonaba a mil pajaritos!'
            'Tetra'                = '¡Tetra se ha ido! Me dijo "hey". ¡Eso es casi un abrazo!'
            'Kevin'                = '¡Kevin se ha ido! ¡Me enseñó su canción! ...¿cómo era? ¡Algo de pizza!'
            'Kennyoung'            = '¡Kenny se ha ido! ¡Hicimos un cover juntos! ...¿cuál era? ¡Da igual, sonó genial!'
            'Enfosi'               = '¡Los Glaggles se han ido! ¡Bailaban como yo delante de la estatua!'
            'Gran'                 = '¡Se ha ido el doctor serio! ¡No me reí ni una vez con él! ¡Ni él conmigo!'
            'Nanachi'                = '¡Nanachi se ha ido! ¡Su estofado me hizo olvidar mi nombre! ...¿cómo me llamaba?'
            'Evil Scary'             = '¡Evil Scary se ha ido! ¡Ya puedo dejar de correr! ...¿por qué corría?'
            'Soft Fuzzy Man'       = '¡Soft Fuzzy Man se ha ido! ...¿quién? ¡Ah, sí! ¡La nube que liga!'
        }
        Yo = @('¡Esa soy yo! ¡Hiii~!', '¡Elígeme! Bailo, canto y me olvido de todo. ¡Es un pack!')
        Opina = @{
            'c00lgui'              = @('c00lgui habla todo en minúsculas. Yo hablo todo en ¡HIII!', 'Le pedí a c00lgui que me hackeara más memoria. Me dio un pan. ¡Gracias!')
            'SeaDrive'             = @('SeaDrive siempre está cansada. Le canto para animarla. Se cansa más.', '¡SeaDrive es mi gata gruñona favorita! Se lo dije. Gruñó. ¡Le gusta!')
            'Static Miku'          = @('¡Miku y yo somos amigas! Ella canta mejor. Yo tengo taladros en el pelo. Empate.', 'Miku dice que soy "la de mentira". ¡Pues aquí sigo! Toma ya.')
            'Guillotina'           = @('Guillotina mira mis coletas como si fueran pan. No lo son. Creo.', 'Le di media baguette a Guillotina. Se comió la baguette entera. Y la otra media.')
            'Angela'               = @('Angela es muy seria. Le hice un baile. Lo apuntó en un informe.', 'Le pregunté a Angela si sabe bailar. Dijo "no consta". ¡Le enseño!')
            'Mikaela'              = @('¡Mikaela tiene unas gafas guays! Le pedí unas. Me dio un hitmarker.', 'Mikaela apunta muy rápido. Yo me distraigo muy rápido. ¡Somos rápidas!')
            'Zodiac'               = @('Zodiac dispara a lo que se mueve. Yo no paro de moverme. Mal plan.', 'Le dije a Zodiac que bailara. Disparó al techo. ¡Eso es un sí!')
            'Velvet'               = @('Velvet tiene una voz muy bonita. ¡Deberíamos cantar juntas! Desde lejos.', 'Velvet dice que soy "un bocado". ¡Gracias! ...espera.')
            'Dune'                 = @('¡Dune es mi mejor amigo! Dice "hiii" igual que yo. Más fuerte.', 'Dune quería mi pan. Le di la mitad. Me quedé con la otra. ¡Amistad!')
            'Cordero y Cabra'      = @('¡El Cordero es adorable! La Cabra da un poco de miedo. Pero baila bien. En secreto.', 'Me invitaron al culto. Pregunté si hay pan. Dijeron "a veces". ¡Me apunto a veces!')
            'Pyrophina y Zaratana' = @('Pyrophina me tostó la baguette. ¡Ahora está más rica! Gracias, lagarta.', 'Me subí encima de Zaratana. Dice que no soy una roca. Yo tampoco lo sabía.')
            'Averi'                = @('¡Averi es como yo pero zorro! Se le olvidan las cosas. ¡Equipo despiste!', 'Averi me regaló un sándwich de pollo. Yo le regalé una canción. ¡Empate!')
            'Sebastian Solace'     = @('Sebastian dice que es "mi único amigo". ¡Qué va! Tengo cinco pájaros.', 'Le pregunté a Sebastian si vende pan francés. Me miró muy raro.')
            'Pursuer'              = @('Pursuer dice "carne fresca". Yo digo "pan fresco". ¡Casi lo mismo!', 'Le dije "hiii" a Pursuer y se quedó quieto. Creo que le caigo bien.')
            'Token'                = @('¡Token baila a 200 BPM! Yo bailo a ritmo de pan. ¡Hacemos buen equipo!', 'Token se pone tiritas. Yo me pongo pan en la cabeza. ¡Moda!')
            'Tetra'                = @('Tetra es de internet como yo. ¡Le mandé un "hiii"! Me lo dejó en visto. ¡Qué guay!', '¡Tetra tiene peces en las orejas! Yo tengo pájaros en la cabeza. ¡Somos un acuario-pajarera!')
            'Kevin'                = @('¡Kevin tiene pizza y yo baguette! ¡Abriremos un restaurante! ...si me deja tocar la pizza. No me deja.', '¡Kevin también es de internet! ¡Su canción y la mía en la misma playlist!')
            'Kennyoung'            = @('¡Kenny es de Corea! ¡Me enseñó a decir "annyeong"! ¡Annyeong! ...¿lo he dicho bien?', '¡Kenny y yo vamos a sacar una canción! Él la escribe y yo me olvido de la letra. ¡Equipo!')
            'Enfosi'               = @('¡Los Glaggles son como yo! Sonríen y se olvidan de todo. Excepto de la estatua.', '¡Le di un Gloobnut a un Gloober! ¡Era falso! ¡Se lo comió igual!')
            'Gran'                 = @('¡Gran dice que sigo siendo humana! ¡Pues claro! ...¿por qué lo dice así?', '¡Le canté una canción y apuntó mi "frecuencia vocal"! ¡Qué fan tan raro!')
            'Nanachi'                = @('¡Nanachi tiene orejas de conejo de verdad! ¡Yo tengo taladros! ¡Somos un dúo de pelo!', '¡Le pregunté si podía tocarle! Dijo "no". ¡Muy claro! ¡Me encanta!')
            'Evil Scary'             = @('¡Me olvidé de que Evil Scary existía! ¡Y entonces sonó la alarma! ¡AAAH!', '¡Le dije "hiii"! ¡Me contestó "STALL, STALL"! ¡Qué maleducado!')
            'Soft Fuzzy Man'       = @('¡Me olvidé de que Soft Fuzzy Man estaba aquí! ¡Él me lo recordó! ¡Cuatro veces!', '¡Le dije "hiii"! ¡Se puso rosa fuerte! ¡Qué mono!')
        }
        Frases = @(
            '¡Abierto! ...creo. ¡Sí, abierto!'
            '¡Listo! Un pajarito te lo ha traído.'
            '¡Hecho! Ni he tenido que pensar. Mejor así.'
            '¡Ta-chán! *Baila un poquito para celebrarlo.*'
        )
        Idle = @(
            'Tengo la cabeza llena de pajaritos. Uno se llama Pan. Los otros también.'
            '¿Sabías que nací como broma del uno de abril? Pues aquí sigo. ¡Hiii!'
            'Mis coletas son taladros. No las toques, que perforan.'
            '¿Pan francés? ¿Alguien ha dicho pan francés? ...nadie. Vale.'
            '*Baila en medio de la calle. Nadie la mira. Le da igual.*'
            'Se me ha olvidado lo que iba a decir. ¡Pero era algo genial!'
            'No soy despistada, soy... ¡ay, mira, un pájaro!'
            'Tengo cerebro de pájaro, pero un corazón enorme. Como una baguette.'
            'Haz clic en mí y te digo hola. ¡Me encanta decir hola!'
            'Cada app que abres atrae a un pajarito. Si se juntan cinco... ¡birdbrain!'
            '*Tararea algo pegadizo. Se equivoca de letra. Sigue igual de feliz.*'
            '31 años. Una vida llena de experiencia. ...¿dónde he dejado las llaves?'
        )
        Clic = @('¡Hiii~!', '¡Hola otra vez! ¿Ya te habías ido?', '*Da una vuelta y casi se cae.* ¡Ta-chán!', '¡Hiii! ...¿qué iba a decir? ¡Ah, sí! ¡Hiii!')
        PorApp = @{
            'YouTube'       = @('¡Pon mi vídeo! El del puente. ¡Salgo guapísima bailando!')
            'Word'          = @('¿Vas a escribir? Escribe "pan". Es mi palabra favorita.')
            'Excel'         = @('Muchas casillas. Como un tablero. ¿Jugamos? ...¿no? Vale.')
            'PowerPoint'    = @('Diapositiva 1: yo. Diapositiva 2: pan. Diapositiva 3: yo con pan.')
            'Outlook'       = @('¡Un correo! ¿Es para mí? ¿Es de un pájaro? ¡Ábrelo!')
            'OneNote'       = @('Apunta: no olvidar nada. ...¿qué no tenía que olvidar?')
            'Access'        = @('¡Uf, esto parece difícil! Me lo miro desde aquí, bailando.')
            'Publisher'     = @('¡Un cartel! "Se busca: pájaro perdido. Responde a Pan."')
            'Teams'         = @('¡Una reunión! ¿Puedo saludar? ¡Hiii a todos!')
            'OneDrive'      = @('¿Tus cosas están en una nube? ¡Los pájaros vuelan cerca!')
            'Office Web'    = @('¡Internet! Busca "pan francés cerca de mí". Por nada.')
            'Bloc de notas' = @('Una hoja en blanco. Como mi cabeza ahora mismo. ¡Qué paz!')
            'Calculadora'   = @('Treinta y uno más uno... ¡sigo teniendo 31! Las cuentas no fallan.')
            'Explorador'    = @('¡A explorar! Como cuando me perdí en el metro. Tres días.')
            'CMD'           = @('Pantalla negra... ¿escribo "hiii"? ¡Lo escribo!')
        }
    }
    # ================================================================ Token (femtanyl)
    'Token' = @{
        Estilo = 'femta'; Titulo = 'TOKEN'; Sub = 'femtanyl  ·  ch4s3r'; Alto = 320
        Fondo = (C 8 4 6); Borde = (C 230 20 40); Acento = (C 255 255 255)
        TituloColor = (C 255 255 255); SubColor = (C 255 60 70)
        BtnFondo = (C 255 255 255); BtnTexto = (C 10 6 8); BtnTextoHover = (C 255 255 255); BtnBorde = (C 10 6 8); BtnBordeAncho = 2
        BtnHover = (C 230 20 40); BtnPress = (C 255 255 255); BarraBtnTexto = (C 10 6 8)
        StatusColor = (C 255 255 255); Fuente = 'Arial Black'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\token\cd1.png'; Logo = 'skins\token\femtanyl_fuego.jpg'; FondoImg = 'skins\token\ciudad.jpg'
        # arte oficial de femtanyl: portadas de su Bandcamp (dibujadas por Noelle Stockwood). Clic en la portada: la siguiente
        Actores = @(
            @{ Id = 'K'; Gif = 'skins\token\cd1.png'; Rect = @(470, 60, 204, 204); Respira = $true
               Extra = @{ cd2 = 'skins\token\cd2.png'; cd3 = 'skins\token\cd3.png'; cd4 = 'skins\token\cd4.png'; cd5 = 'skins\token\cd5.png'; cd6 = 'skins\token\cd6.png'; cd7 = 'skins\token\cd7.png'; cd8 = 'skins\token\cd8.png' } }
        )
        Sonidos = @{
            moneda = @('skins\token\moneda.wav'); golpe = @('skins\token\golpe.wav'); breakcore = @('skins\token\breakcore.wav'); glitch = @('skins\token\glitch.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 10 6 8); BurFuente = 'Consolas'
        Hola = @(
            'T0K3N 1NS3RT3D. ¿Jugamos?'
            '*Entra rompiendo la pantalla. Se pone una tirita.* Hola.'
            'Soy Token. La ficha de la recreativa más ruidosa del mundo. Méteme en algo.'
            '¡H3Y! El volumen está bajo. Súbelo. MÁS.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'El hacker rojo se ha ido. Me ha hackeado una oreja. Me la he vuelto a poner.'
            'SeaDrive'             = 'La gata de los auriculares se ha ido. Le puse breakcore. Se los quitó.'
            'Static Miku'          = 'La tele se ha apagado. Le subí el volumen hasta que hizo BZZT. Fue precioso.'
            'Guillotina'           = 'La gata gigante se fue. Me intentó comer. Sé fatal. Soy de metal.'
            'Angela'               = 'Se ha ido la de la oficina gris. Me puso en contención. Me salí por el altavoz.'
            'Mikaela'              = 'La francotiradora se ha ido. Me dio un hitmarker. Lo llevo de pendiente.'
            'Zodiac'               = 'El vaquero se ha ido. Me dijo "no te muevas". Yo vibro a 180 BPM. Imposible.'
            'Velvet'               = 'La araña se ha ido. Su telaraña no aguantó un drop. Normal.'
            'Dune'                 = 'DUNE SE FUE. DUNE BAILAR BIEN. MEJOR QUE YO NO. PERO BIEN.'
            'Cordero y Cabra'      = 'El culto se ha ido. La Cabra gritó encima de mi canción. Quedó genial, la verdad.'
            'Pyrophina y Zaratana' = 'Las kaijus se han ido. Rompieron la ciudad. Yo rompí el altavoz. Empate.'
            'Averi'                = 'La zorrita se fue. Me puso una tirita con corazones. La dejo puesta.'
            'Sebastian Solace'     = 'El tendero se fue. No vende fichas de recreativa. Inaceptable.'
            'Pursuer'              = 'El bicho del bosque se ha ido. Dice "carne fresca". Yo soy de plástico. Suerte.'
            'Kasane Teto'          = 'Teto se ha ido. Le hice un remix de "hiii" a 200 BPM. Le encantó. Creo.'
            'Tetra'                = 'Tetra se ha ido. Estaba en No molestar. Le molesté igual.'
            'Kevin'                = 'Kevin se ha ido. Le hice un remix. DON''T TOUCH MY PIZZA a 200 BPM. Temazo.'
            'Kennyoung'            = 'Kenny se ha ido. El único que aguantaba mi volumen. Respeto.'
            'Enfosi'               = 'Fin de las oleadas. La estatua sobrevive. Yo también. Como siempre.'
            'Gran'                 = 'EL DOCTOR SE HA IDO. ME QUERÍA PINCHAR. YA ESTOY PINCHADO DE RUIDO.'
            'Nanachi'                = 'Nanachi se ha ido. Me pidió que bajara el volumen. Por primera vez lo hice.'
            'Evil Scary'             = 'Evil Scary se ha ido. Me ha dejado la alarma metida en la cabeza. La he sampleado.'
            'Soft Fuzzy Man'       = 'Soft Fuzzy Man se ha ido. Le metí en un remix. Ahora es un pad ambiental.'
        }
        Yo = @('¡Esa ficha soy yo! Méteme en la máquina.', 'Elígeme. Prometo subir el volumen y no bajarlo nunca.')
        Opina = @{
            'c00lgui'              = @('c00lgui y yo hablamos raro. Él en minúsculas, yo en N0M3R0S.', 'Le pedí a c00lgui que hackeara el volumen. Ahora va del 1 al 11.')
            'SeaDrive'             = @('SeaDrive lleva auriculares todo el día. ¿Qué escucha? ¿Me escucha a mí? Que me escuche a mí.', 'SeaDrive dice que hago mucho ruido. Gracias.')
            'Static Miku'          = @('Miku canta muy bonito. Yo grito muy fuerte. Haríamos un dúo legendario.', 'Le hice un remix a Miku. Se rompió la tele. De emoción.')
            'Guillotina'           = @('Guillotina se lo come todo. Yo soy una ficha. Me tragó y salí por el otro lado. Seguí sonando.', 'Guillotina tiene ritmo. Masticando. A 90 BPM.')
            'Angela'               = @('Angela quiere que me porte bien. ACT RIGHT, dice. Yo no sé.', 'Angela me midió el volumen. Se le rompió el medidor.')
            'Mikaela'              = @('Mikaela dispara a 360. Yo giro a 360. Somos iguales.', 'Los hitmarkers de Mikaela suenan bien. Los quiero en un drop.')
            'Zodiac'               = @('Zodiac dispara a todo lo que se mueve. Yo no paro. Es mi peor enemigo.', 'Le puse breakcore a Zodiac. Disparó al altavoz. Seis veces. Siguió sonando.')
            'Velvet'               = @('Velvet tiene ocho patas. Yo tengo dos orejas enormes. Cada uno con lo suyo.', 'Velvet me invitó a cenar. "DINNER!", grité. Se asustó.')
            'Dune'                 = @('Dune habla en mayúsculas. Como yo cuando me emociono. O sea siempre.', 'DUNE Y TOKEN AMIGOS. DUNE NO ENTENDER BREAKCORE. DA IGUAL.')
            'Cordero y Cabra'      = @('La Cabra grita en el tono perfecto para un drop.', 'El Cordero no dice nada. Le hice un tema. Se llama "...". Es tendencia.')
            'Pyrophina y Zaratana' = @('Dos kaijus peleando. Eso es básicamente un concierto mío.', 'Pyrophina me tostó una oreja. Sigo funcionando. Inmortal.')
            'Averi'                = @('Averi me cura las heridas con tiritas de corazones. Tengo muchas. Me rompo mucho.', 'Averi me dio un sándwich. Me lo comí con el envoltorio. Sabía a victoria.')
            'Sebastian Solace'     = @('Sebastian no vende fichas. ¿Qué clase de tienda es esa?', 'Le pedí volumen a Sebastian. Me vendió unas pilas. Funcionó.')
            'Pursuer'              = @('Pursuer me persiguió. Yo estaba bailando. No me alcanzó.', 'Pursuer da miedo. Yo doy ruido. Hacemos buen equipo.')
            'Kasane Teto'          = @('Teto dice "hiii". Yo digo "H1111". Más fuerte.', 'Teto baila lento. Le subí el BPM. Ahora es un torbellino.')
            'Tetra'                = @('Tetra escucha pop de 2020. Yo le pongo breakcore. Somos muy distintos y me cae genial.', 'Tetra siempre está en No molestar. Yo siempre molesto. Equilibrio.')
            'Kevin'                = @('Kevin grita casi tan fuerte como mi bajo. Casi.', 'Toqué la pizza de Kevin. Sacó una motosierra. Lo convertí en un drop.')
            'Kennyoung'            = @('Kenny hace pop-punk. Yo breakcore. Le remezclé una canción a 200 BPM. Le encantó.', 'Kenny rompió una guitarra. Yo rompí un altavoz. Hicimos un concierto de cosas rotas.')
            'Enfosi'               = @('Los Enphosians explotan en negro. Yo exploto en ruido. Somos primos.', 'Me confundieron con un Glaggle sin cara. Me pegaron con un bate. Ni lo noté.')
            'Gran'                 = @('Gran dice que tengo "buena base genética". GRACIAS. CREO.', 'Su laboratorio es demasiado silencioso. LE PUSE BREAKCORE. NO LE GUSTÓ.')
            'Nanachi'                = @('Nanachi dice que en el Abismo el ruido atrae monstruos. Ahora toco más bajo. Un poco.', 'Probé el estofado de Nanachi. Me crasheé. Literalmente.')
            'Evil Scary'             = @('Evil Scary suena a 60 BPM y luego a 300. Es el mejor drop que he oído.', 'Le hice un remix de la alarma. Botó al ritmo. Mala idea.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man es puro ambiente. Yo soy puro ruido. Hacemos buen equipo.', 'Su canción va a 100 BPM. Le hice una a 200. Se mareó. Es gas.')
        }
        Frases = @(
            '¡T0K3N 1NS3RT3D! Abierto.'
            '*Mete la app en la máquina recreativa.* ¡Listo!'
            '¡Abierto a 180 BPM!'
            '*Lo abre de un cabezazo. Se pone una tirita.*'
        )
        Idle = @(
            '*Le tiembla una oreja. Es el bajo.*'
            'Soy una ficha. Nadie me gasta. Me aburro.'
            '¿Por qué está todo tan callado? Me pone nervioso el silencio.'
            '*Se cae, rebota y sigue como si nada.* Inmortal.'
            'Haz clic en mí muchas veces seguidas. Pasará algo. Algo RUIDOSO.'
            'Cada app que abres es una ficha en la máquina. INSERT TOKEN.'
            '*Mira a la pantalla. Se acerca demasiado. Se aleja.*'
            'Tengo más tiritas que pelo. No tengo pelo.'
            'No me portes bien. ACT RIGHT es solo una canción.'
            '*Cuenta en voz baja.* 1, 2, 3, 4... DROP.'
        )
        Clic = @('¡AU! ...otra vez.', '*Vibra.*', 'MÁS RÁPIDO.', '¡EH!')
        PorApp = @{
            'YouTube'       = @('Pon algo con mucho bajo. MUCHO.')
            'Word'          = @('Escribe en mayúsculas. Todo. Siempre.')
            'Excel'         = @('Muchas casillas. Como un secuenciador. Voy a hacer un ritmo.')
            'PowerPoint'    = @('Diapositiva 1: RUIDO. Diapositiva 2: MÁS RUIDO.')
            'Outlook'       = @('¿Correo? Contesta con "H3Y". Y ya.')
            'OneNote'       = @('Apunta: subir el volumen. Subrayado. Dos veces.')
            'Access'        = @('Esto parece una base de datos. Le meto un drop.')
            'Publisher'     = @('¡Un cartel! Pon mi cara. Con tiritas.')
            'Teams'         = @('Una reunión. Silénciame. No vas a poder.')
            'OneDrive'      = @('Tus archivos en una nube. Yo en una recreativa. Cada uno en su sitio.')
            'Office Web'    = @('Internet abierto. Busca "breakcore a 200 BPM". Por favor.')
            'Bloc de notas' = @('Pantalla en blanco. Como yo. Pero sin tiritas.')
            'Calculadora'   = @('180 por 2... ¡360 BPM! A eso hay que llegar.')
            'Explorador'    = @('Carpetas. Muchas. Ninguna se llama "volumen". Mal.')
            'CMD'           = @('Pantalla negra. Mi favorita. Escribe "rm -rf silencio".')
            'GitHub'        = @('GitHub. Código de otros. Ponle ruido.')
            'Wikipedia'     = @('Busca "femtanyl". Sale una foto mía. Más o menos.')
        }
    }
    # ================================================================ Tetra (YonKaGor)
    'Tetra' = @{
        Estilo = 'pop'; Titulo = 'TETRA'; Sub = "you're just like pop music  ·  yonkagor"; Alto = 320
        Fondo = (C 30 14 52); Borde = (C 255 92 190); Acento = (C 90 230 250)
        TituloColor = (C 255 255 255); SubColor = (C 255 214 120)
        BtnFondo = (C 40 20 70); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 255 255); BtnBorde = (C 90 230 250); BtnBordeAncho = 2
        BtnHover = (C 255 92 190); BtnPress = (C 255 214 120); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 255 255 255); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\tetra\tetra.png'; FondoImg = 'skins\tetra\fondo.jpg'; Logo = 'skins\tetra\failure.png'
        Fotos = @('skins\tetra\mv1.jpg', 'skins\tetra\mv2.jpg', 'skins\tetra\mv3.jpg', 'skins\tetra\mv4.jpg', 'skins\tetra\mv5.jpg')
        # dibujo de Tetra: ficha oficial de YonKaGor (diseño de SentyPurr); fotos del videoclip
        Actores = @(
            @{ Id = 'E'; Gif = 'skins\tetra\tetra.png'; Rect = @(588, 58, 112, 214); Baila = $true }
        )
        Sonidos = @{
            ping = @('skins\tetra\ping.wav'); vhs = @('skins\tetra\vhs.wav'); disco = @('skins\tetra\disco.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 40 20 70); BurTexto = (C 255 255 255); BurFuente = 'Trebuchet MS'
        Hola = @(
            'Hey. Soy Tetra. Pilla una silla, que esto va para largo.'
            '*Se quita un auricular.* ¿Eh? Ah, hola. Estaba escuchando algo de 2020.'
            'Hola. Traigo fideos instantáneos. ¿Quieres? Los míos no, ¿eh?'
            '*Desactiva el No molestar.* Vale. Ya puedes hablarme.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'Se ha ido el hacker. Me ha cambiado la foto de perfil por una calavera. Me gusta.'
            'SeaDrive'             = 'SeaDrive se fue. Somos del mismo creador, ¿sabías? Nos parecemos en lo de no querer hablar.'
            'Static Miku'          = 'Se ha apagado la tele. Miku canta pop de verdad. Yo solo lo escucho.'
            'Guillotina'           = 'La gata gigante se ha ido. Se comió mis fideos. Con el vaso.'
            'Angela'               = 'Se fue Angela. Me hizo un test de sociabilidad. Salí "en No molestar".'
            'Mikaela'              = 'Mikaela se ha ido. Jugamos una partida. Me ganó sin mirar. Respeto.'
            'Zodiac'               = 'El vaquero se ha ido. Me dijo "no te muevas". Estaba en el sofá. No pensaba moverme.'
            'Velvet'               = 'La araña se ha ido. Su voz sonaba muy bien en el chat de voz.'
            'Dune'                 = 'Dune se ha ido nadando. Le enseñé mis pendientes de pez. Se los quería comer.'
            'Cordero y Cabra'      = 'El culto se ha ido. Me invitaron a su grupo. Lo silencié. Sin rencor.'
            'Pyrophina y Zaratana' = 'Las kaijus se han ido. Mucho ruido. Me puse los cascos y ni me enteré.'
            'Averi'                = 'Averi se ha ido. Me mandó cuarenta stickers. Contesté con uno. Es mi récord.'
            'Sebastian Solace'     = 'El tendero se ha ido. Le pregunté si vende fideos. Me vendió una linterna.'
            'Pursuer'              = 'El del bosque se ha ido. Solo se le veían los ojos. Como a mí en las videollamadas.'
            'Kasane Teto'          = 'Teto se ha ido bailando. Teto también es de internet. Nos entendemos.'
            'Token'                = 'Token se ha ido. Por fin silencio. ...vale, lo echo un poco de menos.'
            'Kevin'                = 'Kevin se ha ido. Me mandó una foto de su pizza. La dejé en visto. Ya.'
            'Kennyoung'            = 'Kenny se ha ido. Me escribió. Le contesto mañana. Bueno, un día de estos.'
            'Enfosi'               = 'Se acabaron las oleadas. Me gustaba verlas desde el sofá.'
            'Gran'                 = 'Se ha ido Gran. Me miraba como si fuera un experimento.'
            'Nanachi'                = 'Nanachi se ha ido. No hablamos casi nada. Fue genial.'
            'Evil Scary'             = 'Evil Scary se ha ido. Estaba en No molestar. No sirvió de nada.'
            'Soft Fuzzy Man'       = 'Soft Fuzzy Man se ha ido. Me ha dejado veinte mensajes. Todos dicen "¿me ves?".'
        }
        Yo = @('Ese botón soy yo. Elígeme. Sin prisa.', 'Elígeme y te pongo pop de 2020. Del bueno.')
        Opina = @{
            'c00lgui'              = @('c00lgui escribe en minúsculas. Yo también. Por pereza.', 'c00lgui me hackeó el Discord. Me puso el estado en "jugando". Era verdad.')
            'SeaDrive'             = @('SeaDrive y yo somos de YonKaGor. Somos como primos. Primos que no se escriben.', 'SeaDrive siempre está cansada. Yo siempre estoy tranqui. Parecido.')
            'Static Miku'          = @('Miku es pop puro. Yo soy pop de los recuerdos.', 'Miku me saluda muy fuerte. Me pongo en No molestar. Me saluda más fuerte.')
            'Guillotina'           = @('Guillotina se comió mis fideos. Y el vaso. Y la cuchara.', 'Le puse música a Guillotina. Se comió los auriculares.')
            'Angela'               = @('Angela contesta los mensajes al instante. Yo tardo tres meses. No somos iguales.', 'Angela dice que mi rendimiento es "bajo". Es que estoy en el sofá. Ya me entiendes.')
            'Mikaela'              = @('Mikaela juega muy en serio. Yo juego a cosas sencillas. Tetris. Con calma.', 'Mikaela me hizo un noscope. Yo estaba comiendo fideos. Siguieron calientes.')
            'Zodiac'               = @('Zodiac dispara a lo que se mueve. Yo casi no me muevo. Estoy a salvo.', 'Zodiac me pidió que no me moviera. Lo llevo haciendo desde 2021.')
            'Velvet'               = @('Velvet tiene una voz muy de llamada nocturna. Me gusta.', 'Velvet me mandó un mensaje. Lo vi. No contesté. Clásico.')
            'Dune'                 = @('Dune quiere comerse mis pendientes de pez. Son de oro. No se comen.', 'DUNE QUERER PEZ. TETRA NO SER PEZ. TETRA SER GATO. PERO SE LLAMA PEZ.')
            'Cordero y Cabra'      = @('El Cordero no habla. Me cae bien. Los silencios son lo mejor.', 'La Cabra grita mucho. La tengo silenciada desde enero.')
            'Pyrophina y Zaratana' = @('Dos kaijus peleándose. Lo veo como un directo de Twitch.', 'Pyrophina me calentó los fideos. Con fuego. Quedaron perfectos.')
            'Averi'                = @('Averi me escribe todos los días. Le contesto cada... cuando me acuerdo.', 'Averi es muy cariñosa. Me da un poco de vergüenza. Pero me gusta.')
            'Sebastian Solace'     = @('Sebastian dice que es "tu único amigo". Yo también tuve un único amigo en 2020.', 'Le pedí fideos a Sebastian. Me miró como si fuera raro. Lo raro es que no venda.')
            'Pursuer'              = @('Pursuer persigue a la gente. Yo dejo que la gente se aleje. Cada uno gestiona lo suyo.', 'Pursuer se vuelve invisible. Como yo cuando me llaman por teléfono.')
            'Kasane Teto'          = @('Teto se olvida de todo. Yo me acuerdo de todo. No sé qué es peor.', 'Teto me dijo "hiii". Le contesté "hey". Para mí eso es mucho.')
            'Token'                = @('Token pone la música altísima. Me pongo los cascos. Siguen sonando por encima.', 'Token me hizo un remix de mi canción. A 200 BPM. Ya no la reconozco. Me gusta.')
            'Kevin'                = @('Kevin es muy de 2010. Yo soy muy de 2020. Diez años de internet entre los dos.', 'Kevin no deja tocar su pizza. Yo no dejo tocar mis fideos. Nos entendemos.')
            'Kennyoung'            = @('Kenny es amigo de YonKaGor. Así que más o menos somos amigos. Más o menos.', 'Kenny me pasó una canción suya. People Online. ...me tocó un poco, la verdad.')
            'Enfosi'               = @('Enfosi va de fijarse en los detalles. Yo me fijo en todo. Luego no digo nada.', 'Hay un Glaggle que juega con cohetes y patines. El Gleeber. Mi favorito.')
            'Gran'                 = @('Gran dice que soy la especie superior. Yo solo quiero dormir en el sofá.', 'Me mandó un mensaje. "Su cita para la vacuna es mañana". Lo he dejado en visto.')
            'Nanachi'                = @('Nanachi tampoco contesta mensajes. Por fin alguien que me entiende.', 'Me ofreció estofado. Seguí con mis fideos. Me dijo que era lo más listo que había visto.')
            'Evil Scary'             = @('Evil Scary no respeta el No molestar. Nadie lo respeta, pero él menos.', 'Lo vi venir desde el sofá. Ni me levanté. ...vale, me levanté.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man necesita que le hagan caso. Yo necesito que no me hagan caso. Equilibrio.', 'Le dejé en visto. Se puso transparente. Vale, le contesté.')
        }
        Frases = @(
            'Hecho. Te lo abro como quien abre un chat viejo.'
            '*Abre la app sin levantarse del sofá.*'
            'Listo. Ahora a no hacer nada un rato.'
            'Abierto. Suena a pop, ¿no lo notas?'
        )
        Idle = @(
            '¿Te acuerdas de 2020? Yo sí. Demasiado.'
            '*Mira el móvil. Ningún mensaje. Lo deja.*'
            'Tengo el No molestar puesto desde... ¿desde cuándo?'
            '*Se hace unos fideos instantáneos. Tres minutos exactos.*'
            'Mis pendientes son peces betta. De oro. Nadie se fija. Bueno, tú sí.'
            'Mi gorra pone "Failure". Es broma. Más o menos.'
            '*Tararea algo disco. Muy bajito.*'
            'Hay peces nadando por el fondo. Son tetras, como yo. Bueno, como mi nombre.'
            'Algunos amigos de internet vienen y van. Como las canciones de la radio.'
            '*Juega a algo sencillo en el móvil. Pierde. Vuelve a empezar.*'
            'Haz clic en mí. O no. Tranqui.'
        )
        Clic = @('¿Mm?', 'Hey.', '*Se quita un auricular.* ¿Decías?', '*Saluda con la pata.*')
        PorApp = @{
            'YouTube'       = @('Pon algo de 2020. Ya sabes cuál.')
            'Word'          = @('¿Vas a escribir? Escribe a ese amigo que no te contesta. O no. Tranqui.')
            'Excel'         = @('Una hoja de cálculo. Cuenta los mensajes que no he contestado. Muchos.')
            'PowerPoint'    = @('Diapositiva 1: fideos. Diapositiva 2: sofá. Fin.')
            'Outlook'       = @('Correo nuevo. Lo dejo en visto. Con cariño.')
            'OneNote'       = @('Apunta: contestar mensajes. Lo apunto todos los días.')
            'Access'        = @('Uf. Esto es muy serio. Te miro desde aquí.')
            'Publisher'     = @('¿Un cartel? Ponle letras de neón. Y peces.')
            'Teams'         = @('Videollamada... Cámara apagada. Micro apagado. Perfecto.')
            'OneDrive'      = @('Tus recuerdos en la nube. Como los míos de 2020.')
            'Office Web'    = @('Internet. Donde se hacen amigos. Y donde se pierden.')
            'Bloc de notas' = @('Pantalla en blanco. Qué paz.')
            'Calculadora'   = @('Mensajes sin leer: muchos. Menos tres. Siguen siendo muchos.')
            'Explorador'    = @('Carpetas viejas. Fotos viejas. Ay.')
            'CMD'           = @('Pantalla negra. Muy de hacker. Muy poco de mí.')
            'GitHub'        = @('GitHub. Mucho código. Yo prefiero los fideos.')
            'Wikipedia'     = @('Wikipedia. Busca "neón tetra". Es un pez. Como yo. Más o menos.')
        }
    }
    # ================================================================ Kevin (Don't Touch My Pizza, de Nyanwolf)
    # El lobo verde de la animación de Nyanwolf: vive dentro de un dibujo de Paint y nadie toca su pizza.
    'Kevin' = @{
        Estilo = 'pizza'; Titulo = 'KEVIN'; Sub = "don't touch my pizza  ·  nyanwolf"; Alto = 320
        Fondo = (C 255 255 255); Borde = (C 30 30 30); Acento = (C 70 200 40)
        TituloColor = (C 255 255 255); SubColor = (C 255 236 120)
        BtnFondo = (C 255 255 255); BtnTexto = (C 20 20 20); BtnTextoHover = (C 255 255 255); BtnBorde = (C 20 20 20); BtnBordeAncho = 2
        BtnHover = (C 70 200 40); BtnPress = (C 255 110 200); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 20 20 20); Fuente = 'Comic Sans MS'; FuenteTitulo = 'Comic Sans MS'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\kevin\canta.gif'; PbFondo = (C 255 255 255)
        # GIFs de la animación de Nyanwolf (Tenor), recortados por poses
        Actores = @(
            @{ Id = 'V'; Gif = 'skins\kevin\canta.gif'; Rect = @(498, 90, 248, 172)
               Extra = @{ chulo = 'skins\kevin\chulo.gif'; motosierra = 'skins\kevin\motosierra.gif'; mermelada = 'skins\kevin\mermelada.gif'; grita = 'skins\kevin\grita.gif'
                          trabajo = 'skins\kevin\trabajo.gif'; arma = 'skins\kevin\arma.gif'; muerde = 'skins\kevin\muerde.gif'; feliz = 'skins\kevin\feliz.gif'; fuego = 'skins\kevin\fuego.gif'
                          sudor = 'skins\kevin\sudor.gif'; piensa = 'skins\kevin\piensa.gif'; baile = 'skins\kevin\baile.gif'; micro = 'skins\kevin\micro.gif'; unicornio = 'skins\kevin\unicornio.gif' } }
        )
        Sonidos = @{
            polka = @('skins\kevin\polka.mp3'); baile = @('skins\kevin\polka_baile.mp3')
            nam = @('skins\kevin\nam.wav'); grr = @('skins\kevin\grr.wav'); ding = @('skins\kevin\ding.wav'); grito = @('skins\kevin\grito.wav'); pop = @('skins\kevin\pop.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 20 20 20); BurFuente = 'Comic Sans MS'
        Hola = @(
            '¡HOLA! Soy Kevin. Esa pizza de ahí es MÍA. Solo para que quede claro.'
            '*Sale del dibujo de Paint.* ¿Has traído pizza? ...¿no? Vale. Pero la mía no se toca.'
            '¡RAWR XD! Bienvenido a mi Paint. Puedes tocar los botones. La pizza NO.'
            'Hola, hola. Regla número uno: no toques mi pizza. Regla número dos: mira la regla uno.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'El hacker rojo se ha ido. Intentó hackear mi pizza. Le mordí el teclado.'
            'SeaDrive'             = 'Se fue la gata de los auriculares. Me dijo que gritaba mucho. NO GRITO. ...vale, un poco.'
            'Static Miku'          = '¡Se apagó la tele! Miku me cantó una canción. Yo le canté la mía. Ganó la mía.'
            'Guillotina'           = 'La gata gorda se ha ido. Miró mi pizza. Yo la miré a ella. Ganó la pizza.'
            'Angela'               = 'Se fue la de la oficina. Quería meter mi pizza en "contención". JAMÁS.'
            'Mikaela'              = 'La francotiradora se ha ido. Apuntó a mi pizza. Casi le muerdo el rifle.'
            'Zodiac'               = 'El vaquero se fue. Me dijo "no te muevas". Yo tampoco quería moverme. Estaba comiendo.'
            'Velvet'               = 'La araña se ha ido. Me invitó a cenar. Le pregunté si había pizza. Dijo "algo mejor". NADA es mejor.'
            'Dune'                 = 'Se fue el bicho del agua. Dijo "DUNE COMER PIZZA". DUNE NO COMER PIZZA.'
            'Cordero y Cabra'      = 'El culto se ha ido. Me pidieron una ofrenda. Les di la caja de la pizza. Vacía.'
            'Pyrophina y Zaratana' = 'Las kaijus se fueron. Pyrophina me calentó la pizza. Al fin una kaiju útil.'
            'Averi'                = 'Se fue la zorrita. Me cambió un sándwich de pollo por un trozo. Mal negocio. Para ella.'
            'Sebastian Solace'     = 'El tendero se ha ido. No vende pizza. ¿Qué clase de tienda es esa?'
            'Pursuer'              = 'El del bosque se fue. Dijo "carne fresca". Le dije que la pizza era de pepperoni. Se fue triste.'
            'Kasane Teto'          = 'Teto se ha ido. Cambiamos comida: su baguette por mi... no. Mi pizza no se cambia.'
            'Token'                = 'Token se ha ido. Me hizo un remix de mi canción. A 200 BPM. Un temazo, la verdad.'
            'Tetra'                = 'Tetra se ha ido. Le mandé una foto de mi pizza. Me dejó en visto. Grosero.'
            'Kennyoung'            = 'Se fue Kenny. Tocó la guitarra cerca de mi pizza. No la tocó a ella. Vive.'
            'Enfosi'               = '¡Se han ido los Glaggles! ¡Ninguno ha tocado mi pizza! ¡BIEN!'
            'Gran'                 = '¡SE HA IDO EL DOCTOR! ¡NO HA TOCADO MI PIZZA! ...¿O SÍ? *La revisa.*'
            'Nanachi'                = 'Se fue el conejo. Su estofado sabe peor que el queso azul. ¡Y no lo toqué! ...bueno, lo probé.'
            'Evil Scary'             = '¡Se fue Evil Scary! ¡Y no tocó mi pizza! ...me tocó a mí. Que es peor.'
            'Soft Fuzzy Man'       = '¡Se fue la nube! ¡Ha pasado a través de mi pizza! ¡Dice que no la ha tocado! ...técnicamente tiene razón.'
        }
        Yo = @('¡Ese soy yo! El lobo más guapo de todo Paint.', 'Elígeme. Pero trae pizza. Para ti no, para mí.')
        Opina = @{
            'c00lgui'              = @('c00lgui intentó hackear mi pizza. Le puse un cortafuegos. De queso.', 'c00lkidd dice que es un hacker. Yo digo que no sabe pedir una pizza por internet.')
            'SeaDrive'             = @('SeaDrive siempre está cansada. Yo con una pizza me curo de todo.', 'SeaDrive me dijo que bajara la voz. ¡¿QUÉ?! ¡NO TE OIGO!')
            'Static Miku'          = @('Miku canta muy bien. Pero no ha sacado ninguna canción sobre pizza. Fallo.', 'Le dejé a Miku cantar el estribillo de mi canción. Una vez. No más.')
            'Guillotina'           = @('Guillotina se come gatos enteros. Mientras no se coma MI pizza, somos amigos.', 'Guillotina y yo nos miramos fijamente durante una hora. Por una pizza. Nadie parpadeó.')
            'Angela'               = @('Angela dice que mi nivel de amenaza es "ZAYIN". Por tocar mi pizza sube a "ALEPH".', 'Angela me preguntó por qué me enfado tanto por una pizza. No lo entendería. No come.')
            'Mikaela'              = @('Mikaela hace 360 noscopes. Yo hago 360 mordiscos. A la pizza.', 'Mikaela dice "GG EZ". Yo digo "PIZZA EZ".')
            'Zodiac'               = @('Zodiac le dispara a todo lo que se mueve. Mi pizza no se mueve. Mi pizza está a salvo.', 'Zodiac me apuntó. Yo saqué mi cuchillo. Y mi pistola. Empate técnico.')
            'Velvet'               = @('Velvet me invitó a su telaraña. Le dije que solo voy si hay pizza.', 'Velvet dice que soy "un bocado tierno". Yo soy el que muerde aquí.')
            'Dune'                 = @('Dune quiere comerse mi pizza. DUNE NO TOCAR. DUNE ENTENDER.', 'Dune habla en mayúsculas. Como yo cuando alguien toca mi pizza.')
            'Cordero y Cabra'      = @('El culto me ofreció ser obispo. Pregunté si se cena pizza. "A veces." ...me lo pienso.', 'La Cabra grita casi tan fuerte como yo. CASI.')
            'Pyrophina y Zaratana' = @('Pyrophina tiene fuego. Puede hacer pizzas al horno. La quiero en mi equipo.', 'Zaratana se mete en su caparazón. Yo me meto en la caja de la pizza. Somos iguales.')
            'Averi'                = @('Averi me dio medio sándwich. Yo le di media sonrisa. Es lo justo.', 'Averi dijo que mi pizza "huele raro". QUIERE DECIR QUE HUELE BIEN. Lo sé.')
            'Sebastian Solace'     = @('Sebastian vende linternas. Yo no necesito linternas. Mi pizza brilla con luz propia.', 'Le pregunté a Sebastian si tenía pizza. Me vendió unas pilas. No están buenas.')
            'Pursuer'              = @('Pursuer dice "carne fresca". Yo digo "pizza fresca". Somos muy parecidos.', 'Pursuer se vuelve invisible. Mi pizza también, cuando me la como.')
            'Kasane Teto'          = @('Teto tiene pan francés. Yo tengo pizza italiana. Guerra de panes.', 'Teto se olvida de todo. Yo nunca me olvido de quién tocó mi pizza.')
            'Token'                = @('Token y yo somos de internet. Él suena fuerte. Yo grito fuerte. Equipo.', 'Token me hizo un remix. "DON''T TOUCH MY PIZZA" a 200 BPM. Lo pongo en bucle.')
            'Tetra'                = @('Tetra come fideos instantáneos. Respeto, pero la pizza es mejor.', 'Tetra tiene el No molestar puesto. Yo tengo el No tocar mi pizza puesto. Siempre.')
            'Kennyoung'            = @('¡Kenny! ¡Hazme una canción pop-punk sobre mi pizza! ¡Que se llame NO LA TOQUES!', 'Kenny rompe guitarras. Yo rompo cosas cuando tocan mi pizza. Nos entendemos.')
            'Enfosi'               = @('Los Glaggles defienden una estatua. Yo defiendo una pizza. MUCHO más importante.', '¡Un Gembo me tiró una bola explosiva a la pizza! ¡ERA UN ENPHOSIAN! ¡LO SABÍA!')
            'Gran'                 = @('¡Gran quería ponerle Fury Mix a mi pizza! ¡NADIE TOCA MI PIZZA! ¡NI LA CIENCIA!', 'Me dijo que mi instinto animal es "correcto". Gracias. Ahora vete de mi pizzería.')
            'Nanachi'                = @('Nanachi defiende su olla como yo mi pizza. Respeto. Pero su olla huele fatal.', 'Le ofrecí... nada. No toques mi pizza. Pero Nanachi mola.')
            'Evil Scary'             = @('¡Le saqué la motosierra! ¡Se le rompió! ¡A la motosierra!', 'Evil Scary no quiere mi pizza. Quiere a Kevin. Kevin soy yo. AAAAH.')
            'Soft Fuzzy Man'       = @('¡Soft Fuzzy Man no puede tocar mi pizza! ¡Es el amigo perfecto!', '¡Ahora mi pizza sabe a niebla rosa! ¡NO TOQUES MI PIZZA! ¡Ni de vapor!')
        }
        Frases = @(
            '¡Abierto! Y no he tocado nada. Bueno, un trozo de pizza. Era mío.'
            '*Lo abre con la pata llena de queso.* ¡Listo!'
            '¡Hecho! Esto se merece otro trozo.'
            '¡TA-DA! ...*ÑAM.*'
        )
        Trabajo = @(
            '*Se sienta a trabajar en el ordenador... y se cae de la silla.* Estoy bien. ESTOY BIEN.'
            'Hora de trabajar. *Se sienta. Se resbala. Se cae.* ...la silla estaba mojada de salsa.'
            '¡Modo productivo! *Plof.* Vale, modo suelo.'
        )
        Idle = @(
            '*Mira su pizza. La pizza le mira. Amor verdadero.*'
            'Si tocas mi pizza, te muerdo. Es una amenaza. Pero dicha con cariño.'
            'No me gusta el queso azul. Huele fatal. ¿Quién inventó eso?'
            '*Canta bajito.* Don''t touch my pizza... na na na...'
            '¿Sabías que me llaman Kevin? Como Kevin MacLeod. El de la música. Somos casi primos.'
            'Mi camiseta favorita pone "WHY HATE?". Porque, ¿por qué odiar? Bueno, salvo a los que tocan mi pizza.'
            '*Rawr XD.* ...¿Eso ya no se dice? En Paint sigue siendo 2010.'
            'Haz clic en mí y bailo. Haz clic en la pizza y... mejor no lo hagas.'
            'Cada app que abres es un trozo que me como. Tú trabajas, yo como. Trato justo.'
            'Tampoco toques mi mermelada. Nadie toca mi mermelada.'
            '*Huele algo.* ...¿Huele a queso azul? Si alguien ha puesto queso azul, que se prepare.'
            '*Saluda a un unicornio que pasa. El unicornio no le saluda.*'
        )
        Clic = @('¡EH! Que no soy una pizza.', '¿Qué? ¿Quieres un trozo? NO.', '*Te mira de reojo.* Tú no habrás tocado nada, ¿verdad?', '¡Hola! *Esconde la pizza detrás de la espalda.*')
        PorApp = @{
            'YouTube'       = @('Pon "Don''t Touch My Pizza". La de verdad. Diez veces.', 'YouTube. Busca recetas de pizza. Para mí, claro.')
            'Word'          = @('Escribe una carta de amor. A la pizza. Yo te la dicto.')
            'Excel'         = @('Una tabla: Pizzas comidas, muchas. Pizzas tocadas por otros, CERO.')
            'PowerPoint'    = @('Diapositiva 1: pizza. Diapositiva 2: no tocar la pizza. Fin.')
            'Outlook'       = @('¿Correo? Pide una pizza por correo. ¿Eso se puede? Debería poderse.')
            'OneNote'       = @('Apunta: comprar pizza. Apunta: esconder pizza. Apunta: morder al que la toque.')
            'Access'        = @('Una base de datos. Mete a todos los que han tocado mi pizza. Lista negra.')
            'Publisher'     = @('¡Un cartel! "SE BUSCA: el que tocó mi pizza". Con mi cara enfadada.')
            'Teams'         = @('Reunión. Si alguien pregunta, estoy comiendo. Porque estoy comiendo.')
            'OneDrive'      = @('Tus archivos en la nube. Mi pizza en mi estómago. Cada cosa en su sitio.')
            'Office Web'    = @('Internet. Busca "pizza a domicilio". ¡Venga, venga!')
            'Bloc de notas' = @('Hoja en blanco. Como mi Paint antes de dibujar la pizza.')
            'Calculadora'   = @('Una pizza tiene ocho trozos. Ocho trozos para mí. Cero para ti. Las matemáticas no mienten.')
            'Explorador'    = @('Busca en tus carpetas. ¿Hay alguna que se llame "pizza"? Debería.')
            'CMD'           = @('Pantalla negra. Escribe: "no toques mi pizza". Ejecutar. Hecho.')
            'GitHub'        = @('GitHub. Mucho código. Ni una sola pizza. Qué triste.')
            'Wikipedia'     = @('Wikipedia. Busca "pizza". Lee en voz alta. Muy despacio.')
        }
        Toque1 = @('¡¡NO TOQUES MI PIZZA!! *Saca un cuchillo y una pistola de la nada.*', '¡EH! ¡ESA PIZZA ES MÍA! *Te apunta con el cuchillo.* Primer aviso.', '¡¿HAS TOCADO MI PIZZA?! *Se le eriza el pelo rosa.*')
        Toque2 = @('I''M GOING TO BITE YOU. ...lo digo en serio. Segundo aviso.', '*Enseña los dientes.* La próxima vez te muerdo. De verdad. Grrr.', '¡OTRA VEZ! ¡¿POR QUÉ?! *Muerde el aire en tu dirección.*')
        Rabia = @('¡¡¡SE ACABÓ!!! *Saca una motosierra y TODO arde.* ¡¡NO. TOQUES. MI. PIZZA!!', '¡¡ESTO ES LA GUERRA!! *La pantalla se llena de fuego.* ¡¡QUIERO PIZZA Y QUIERO PAZ!!', '*RAWR.* *Fuego por todas partes.* ...vale. Ya me he desahogado. NO LO VUELVAS A HACER.')
    }
    # ================================================================ Kennyoung (músico y animador surcoreano de pop-punk)
    # Su personaje de los videoclips, dentro del reproductor de su canal de YouTube.
    'Kennyoung' = @{
        Estilo = 'punk'; Titulo = 'Kennyoung'; Sub = ''; Alto = 320; TituloX = 44
        # estética de sus dibujos: atardecer en el skatepark, borde verde de pegatina y la camisa de cuadros marrón
        Fondo = (C 250 190 150); Borde = (C 70 50 45); Acento = (C 110 235 140)
        TituloColor = (C 255 255 255); SubColor = (C 110 235 140)
        BtnFondo = (C 255 248 240); BtnTexto = (C 70 50 45); BtnTextoHover = (C 30 24 22); BtnBorde = (C 70 50 45); BtnBordeAncho = 2
        BtnHover = (C 110 235 140); BtnPress = (C 255 200 120); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 70 50 45); Fuente = 'Segoe UI'; FuenteTitulo = 'Ink Free'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\kennyoung\habla_cerrada.png'; PbFondo = (C 250 196 160); Avatar = 'skins\kennyoung\avatar.png'
        FondoImg = 'skins\kennyoung\fondo_atardecer.jpg'
        # Kenny (dibujo con la boca cerrada) y las dos bocas abiertas para cuando habla
        Actores = @(
            @{ Id = 'Y'; Gif = 'skins\kennyoung\habla_cerrada.png'; Rect = @(500, 46, 258, 272); Respira = $true
               Extra = @{ abierta1 = 'skins\kennyoung\habla_abierta1.png'; abierta2 = 'skins\kennyoung\habla_abierta2.png' } }
        )
        # mientras se escribe el bocadillo, va cambiando de boca en este orden ('main' es la boca cerrada)
        Habla = @{ Id = 'Y'; Bocas = @('abierta1', 'abierta2', 'abierta1', 'main') }
        # GIFs de sus videoclips (Tenor) para el minirreproductor de su canal: archivo y título
        Videos = @{
            guitarra = @('skins\kennyoung\guitarra.gif', 'Someday'); concierto = @('skins\kennyoung\concierto.gif', 'Can''t Keep My Hands Off You (cover)')
            loner = @('skins\kennyoung\loner.gif', 'Loner'); online = @('skins\kennyoung\online.gif', 'People Online'); nada = @('skins\kennyoung\nada.gif', 'Nothing')
            piensa = @('skins\kennyoung\piensa.gif', 'I Used To'); triste = @('skins\kennyoung\triste.gif', 'Get Away'); calavera = @('skins\kennyoung\calavera.gif', 'Baby, You''re A Haunted House (cover)')
            kaboom = @('skins\kennyoung\kaboom.gif', '¡KABOOM!'); diablo = @('skins\kennyoung\diablo.gif', 'DON''T PLAY'); yap = @('skins\kennyoung\yap.gif', 'yap')
        }
        Sonidos = @{
            acorde = @('skins\kennyoung\acorde.wav', 'skins\kennyoung\acorde2.wav', 'skins\kennyoung\acorde3.wav'); riff = @('skins\kennyoung\riff.wav')
            kaboom = @('skins\kennyoung\kaboom.wav'); publico = @('skins\kennyoung\publico.wav'); campana = @('skins\kennyoung\campana.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 246 236); BurTexto = (C 60 42 38); BurFuente = 'Trebuchet MS'
        Canciones = @('Someday', 'Maybe Tomorrow', 'Let''s Go', 'Nothing', 'See You!', 'People Online', 'Loner', 'I Used To', 'Parasocial', 'Ready To Say', 'Good Old Green Days', 'Get Away', 'Lethargy', 'Taste of Summer', 'Trash Talkin''')
        Hola = @(
            '¡Annyeong! Soy Kenny. Bueno, Kennyoung. Bueno, como quieras. Pilla una guitarra.'
            '*Afina la guitarra.* Ah, hola. Estaba ensayando. O eso parece desde fuera.'
            'Hey. Bienvenido al canal. Dale a suscribirse. ...es broma. Bueno, no del todo.'
            '¡Hey! Hoy toca pop-punk. Mañana también. Siempre toca pop-punk.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'El hacker se ha ido. Me ha cambiado la contraseña del canal por "c00lkidd". ...era mejor que la mía.'
            'SeaDrive'             = 'Se fue SeaDrive. YonKaGor me habla mucho de ella. Dice que es gruñona. Lo confirmo.'
            'Static Miku'          = 'Se apagó la tele de Miku. Le pedí un feat. Me dijo "¡bzzt!". Lo tomo como un sí.'
            'Guillotina'           = 'La gata gigante se ha ido. Se comió una púa. Y luego el amplificador.'
            'Angela'               = 'Se fue Angela. Me pidió que bajara el volumen. Lo subí. Los punks somos así.'
            'Mikaela'              = 'Se fue Mikaela. Le hizo un noscope a mi guitarra. Le dediqué un solo como venganza.'
            'Zodiac'               = 'El vaquero se fue. Me dijo "no te muevas". Estaba en pleno concierto, tío. Imposible.'
            'Velvet'               = 'Se fue Velvet. Tiene voz para un dueto. Pero me da miedo cenar con ella.'
            'Dune'                 = 'Se fue Dune. "DUNE GUSTAR GUITARRA", me dijo. Gracias, Dune. Mejor crítica que he tenido.'
            'Cordero y Cabra'      = 'Se fue el culto. La Cabra grita mejor que muchos cantantes de punk que conozco.'
            'Pyrophina y Zaratana' = 'Se fueron las kaijus. Pyrophina me quemó el setlist. Toqué de memoria.'
            'Averi'                = 'Se fue Averi. Me dijo que mi música es "ruidosa". Quería decir "guay". Creo.'
            'Sebastian Solace'     = 'Se fue el tendero. No vende cuerdas de guitarra. Tienda inútil para un músico.'
            'Pursuer'              = 'Se fue el del bosque. Le enseñé un acorde. Se fue corriendo. Igual era el acorde.'
            'Kasane Teto'          = 'Teto se ha ido. Hicimos un cover juntos. Ella cantaba, yo tocaba y nadie se sabía la letra.'
            'Token'                = 'Token se ha ido. Él hace breakcore, yo pop-punk. El volumen, igual de alto.'
            'Tetra'                = 'Se fue Tetra. Es de YonKaGor, como SeaDrive. Le escribí. Me dejó en visto. Típico de su casa.'
            'Kevin'                = 'Se fue Kevin. Le toqué la pizza sin querer. Me persiguió con una motosierra. Buen ritmo, eso sí.'
            'Enfosi'               = 'Se acabaron las oleadas. Les hice una canción a los Glaggles. Explotaron. De alegría, creo.'
            'Gran'                 = 'Se ha ido Gran. Le toqué una canción y la apuntó como "síntoma".'
            'Nanachi'                = 'Se fue Nanachi. Le toqué algo tranquilo para que se durmiera. Funcionó.'
            'Evil Scary'             = 'Se fue Evil Scary. La alarma del avión sonaba en Mi bemol. Ya tengo canción.'
            'Soft Fuzzy Man'       = 'Se fue Soft Fuzzy Man. Su canción es de Lemon Demon. Le toqué la línea de bajo. Se puso a bailar.'
        }
        Yo = @('¡Ese soy yo! Bueno, mi personaje. Es más guapo que yo. Y toca mejor.', 'Elígeme. Prometo no romper ninguna guitarra. ...hoy.')
        Opina = @{
            'c00lgui'              = @('c00lgui escribe en minúsculas. Como mis letras cuando tengo prisa.', 'c00lkidd me hackeó el canal y subió un vídeo de 10 horas de glitch. Tuvo más visitas que yo.')
            'SeaDrive'             = @('SeaDrive es de YonKaGor. Nos conocemos de lejos. Muy de lejos. Ella prefiere así.', 'SeaDrive tiene cara de cansada. Yo también. Somos un club.')
            'Static Miku'          = @('Miku canta perfecto. Yo canto con ganas. No es lo mismo, pero vale.', 'Le pedí a Miku que cantara pop-punk. Le salió precioso. Me dio rabia.')
            'Guillotina'           = @('Guillotina se comió mi púa favorita. La echo de menos. A la púa.', 'Si Guillotina viene a un concierto, que se quede atrás. Por la gente.')
            'Angela'               = @('Angela dice que mi música es "un riesgo para la productividad". Gracias. Lo pondré en la camiseta.', 'Angela me cronometró una canción. Dos minutos y medio. "Eficiente", dijo.')
            'Mikaela'              = @('Mikaela juega como yo toco: rápido y sin pensar.', 'Mikaela me pidió una canción para sus clips. Le hice una. Tiene hitmarkers de batería.')
            'Zodiac'               = @('Zodiac le dispara a lo que se mueve. En mis conciertos se mueve todo el mundo. Mal plan.', 'Zodiac me pidió una canción del oeste. Le hice pop-punk con armónica. No le gustó.')
            'Velvet'               = @('Velvet tiene voz de cantante de los 2000. Le falta una banda. Y que no se coma a la banda.', 'Velvet me invitó a cenar. Le dije que tenía ensayo. Tenía ensayo todos los días. Para siempre.')
            'Dune'                 = @('Dune habla como mis letras de 2016. Todo en mayúsculas.', 'Le dejé tocar la batería a Dune. Se la comió.')
            'Cordero y Cabra'      = @('La Cabra grita perfecto para un coro de punk. Le ofrecí unirse a The Lazy Tails.', 'El Cordero no habla. Sería un bajista genial.')
            'Pyrophina y Zaratana' = @('Pyrophina y Zaratana peleándose suenan como un solo de batería.', 'Le pedí a Pyrophina efectos de fuego para un concierto. Quemó el escenario. Muy punk.')
            'Averi'                = @('Averi es muy maja. Me trajo un sándwich al ensayo. Se lo comió ella.', 'Averi dice cosas raras sin querer. Como mis letras.')
            'Sebastian Solace'     = @('Sebastian no vende cuerdas. Ni púas. Ni nada útil para mí.', 'Sebastian me ofreció una linterna para el escenario. No es mala idea.')
            'Pursuer'              = @('Pursuer toca la armónica. Podríamos hacer un tema. Si deja de perseguirme.', 'Pursuer vino a un concierto. Dijo "carne fresca" mirando al público. Se cancelaron dos entradas.')
            'Kasane Teto'          = @('Teto se olvida de las letras. Yo también. Por eso cantamos el estribillo cinco veces.', 'Teto me dio media baguette. La usé de baqueta. Funcionó.')
            'Token'                = @('Token hace breakcore. Yo pop-punk. Los dos rompemos altavoces.', 'Token me remezcló una canción a 200 BPM. Ahora dura 40 segundos. Me gusta más.')
            'Tetra'                = @('Tetra es de YonKaGor. Como SeaDrive. Todos los de su casa contestan tarde.', 'Tetra escucha pop de 2020. Yo hacía pop-punk en 2020. Somos de la misma época.')
            'Kevin'                = @('Kevin tiene una canción sobre su pizza. Muy pop-punk, la verdad. Corta y gritona.', 'Le pedí a Kevin un trozo de pizza. No sé qué pasó después. Me desperté lejos.')
            'Enfosi'               = @('El Giggler tiene una guitarra que aturde a los Enphosians. Necesito esa guitarra.', 'La música de las oleadas está muy bien. "Enphosed", de raleigh. Me la apunto.')
            'Gran'                 = @('Gran escucha la canción del ascensor de Regretevator. "¿Seguro que es farmacéutico?" ...pues no, no lo es.', 'Dice que con garras tocaría mejor la guitarra. Igual tiene razón. No pienso comprobarlo.')
            'Nanachi'                = @('Nanachi tiene orejas grandes y cola. Casi somos familia. Casi.', 'Le hice una canción sobre su estofado. Se titula "Mejor no".')
            'Evil Scary'             = @('Evil Scary bota a 100 BPM. Luego a 200. Pop-punk puro.', 'Le toqué un acorde para calmarlo. El ampli explotó. Él siguió.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man tiene una de las mejores canciones de Spirit Phone. No se lo digas, que ya se lo cree.', 'Le hice un acorde. Vibró entero. Literalmente.')
        }
        Frases = @(
            'Abierto. Como un primer acorde: fuerte y sin pensarlo mucho.'
            '*Rasguea.* ¡Listo!'
            'Hecho. Una visita más al canal. Gracias.'
            'Abierto. ¡Uno, dos, tres, cuatro!'
        )
        Idle = @(
            '*Afina la guitarra. Desafina la guitarra. La vuelve a afinar.*'
            'Estoy componiendo. O mirando el techo. Desde fuera es igual.'
            'Mi música está inspirada en Blink-182, Green Day y Simple Plan. Y en no dormir.'
            '¿Sabías que tengo una banda? The Lazy Tails. Somos vagos. Está en el nombre.'
            '*Se queda mirando la pantalla del portátil.* La gente de internet... qué gente.'
            'Haz clic en mí y toco. Muchos clics seguidos y... bueno, ya verás. Trae extintor.'
            'Si te gusta el vídeo, dale a like. Si no te gusta, dale a like igual.'
            '*Toca un acorde muy bajito para no molestar. Molesta igual.*'
            'Tengo más covers que canciones mías. Los covers son más fáciles de terminar.'
            '¿Tú también escuchas música para no pensar? Yo la hago para lo mismo.'
            '*Mira el atardecer desde el balcón.* Esto pide una canción. Mañana la escribo.'
            '"Annyeong" es "hola" en coreano. Ya puedes saludarme bien.'
        )
        Clic = @('¿Eh? Ah, hola.', '*Te saluda con la púa.*', '¿Pedías una canción?', '*Sigue tocando sin mirar.*')
        PorApp = @{
            'YouTube'       = @('YouTube. Busca "kennyoung". Es para un amigo. Que soy yo.', 'YouTube. Tengo un canal ahí, ¿sabes? Igual te suena.')
            'Word'          = @('Escribe una letra. Algo sobre el verano. O sobre no tener ganas de nada. Las dos funcionan.')
            'Excel'         = @('Una tabla. Columna 1: acordes. Columna 2: los mismos acordes. El pop-punk es así.')
            'PowerPoint'    = @('Diapositiva 1: pop-punk. Diapositiva 2: más pop-punk. Fin del concierto.')
            'Outlook'       = @('¿Correo? Si es una colaboración, di que sí. Si es de trabajo, di que estoy de gira.')
            'OneNote'       = @('Apunta: ensayar. Lo apunto todos los días. No ensayo todos los días.')
            'Access'        = @('Una base de datos. Mete todos mis covers. Va a tardar.')
            'Publisher'     = @('¡Un cartel para el concierto! Letras grandes, algo pintado a mano y una estrella.')
            'Teams'         = @('Reunión. Pon la cámara. Yo me pongo la capucha.')
            'OneDrive'      = @('Guárdame las maquetas en la nube. Hay 47. Todas se llaman "final_final_ahorasí".')
            'Office Web'    = @('Internet. People online. Mi canción favorita. Mía.')
            'Bloc de notas' = @('Hoja en blanco. Perfecta para una letra. O para mirarla fijamente una hora.')
            'Calculadora'   = @('172 BPM. Velocidad perfecta para el pop-punk. Lo dicen las matemáticas.')
            'Explorador'    = @('Busca la carpeta "Canciones sin terminar". Pesa más que todo lo demás.')
            'CMD'           = @('Pantalla negra. Como mi sudadera. Y mi humor a las 8 de la mañana.')
            'GitHub'        = @('GitHub. Código. Como acordes, pero sin guitarra.')
            'Wikipedia'     = @('Wikipedia. Busca "pop-punk". Me sale a mí al lado. Más o menos.')
        }
        Kaboom = @('*Toca tan fuerte que la guitarra EXPLOTA.* ...vale. Era la guitarra buena.', '¡KABOOM! *Queda solo el mástil.* Esto se llama "pop-punk de verdad".', '*La guitarra explota.* ¡TODO EL MUNDO ESTÁ BIEN! ...¿todo el mundo está bien?')
        Concierto = @('¡Esto ya es un concierto! *El público grita.* ¡GRACIAS! ¡SOIS LOS MEJORES! ...somos cuatro.', '¡ENCORE! ¡ENCORE! *Toca otra vez la misma canción. Nadie se queja.*', '*Sube al escenario con la banda.* ¡Uno, dos, tres, cuatro!')
    }
    # ================================================================ Enfosi (Roblox, de Tumore)
    # Datos sacados de las wikis del juego (enfosi.miraheze.org y enfosi-tumore.fandom.com)
    'Enfosi' = @{
        Estilo = 'enfosi'; Titulo = 'ENFOSI'; Sub = 'tumore  ·  roblox'; Alto = 320
        Fondo = (C 30 34 48); Borde = (C 40 30 10); Acento = (C 255 214 60)
        TituloColor = (C 40 30 10); SubColor = (C 90 60 10)
        BtnFondo = (C 255 255 255); BtnTexto = (C 25 25 25); BtnTextoHover = (C 25 25 25); BtnBorde = (C 25 25 25); BtnBordeAncho = 2
        BtnHover = (C 255 214 60); BtnPress = (C 255 170 20); BarraBtnTexto = (C 25 25 25)
        StatusColor = (C 255 255 255); Fuente = 'Arial Rounded MT Bold'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\enfosi\giggler_baila.gif'; Logo = 'skins\enfosi\logo.png'; FondoImg = 'skins\enfosi\fondo.jpg'
        # la estatua (un Giggler gigante en un pedestal de oro) y el Glaggle que camina hacia ella
        Actores = @(
            @{ Id = 'E'; Gif = 'skins\enfosi\estatua.png'; Rect = @(402, 96, 128, 172) }
            @{ Id = 'W'; Gif = 'skins\enfosi\giggler.png'; Rect = @(820, 148, 74, 120); Extra = $EnfosiPoses }
        )
        Sonidos = @{
            golpe = @('skins\enfosi\golpe.wav'); buzzer = @('skins\enfosi\buzzer.wav'); revela = @('skins\enfosi\revela.wav'); ojo = @('skins\enfosi\ojo.wav')
            ola = @('skins\enfosi\ola.wav'); confeti = @('skins\enfosi\confeti.wav'); estatua = @('skins\enfosi\estatua.wav'); moneda = @('skins\enfosi\moneda.wav')
            ding = @('skins\enfosi\ding.wav'); alarma = @('skins\enfosi\alarma_jefe.mp3')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 255 255 255); BurTexto = (C 25 25 25); BurFuente = 'Arial Rounded MT Bold'
        Hola = @(
            '¡Defiende la estatua! Los Glaggles son buenos... casi todos.'
            'Bienvenido a Enfosi. 7 oleadas, una estatua y algún Enphosian disfrazado.'
            '¡Glaggles en camino! Fíjate en su color, en su cara y en el símbolo de su camiseta.'
            'Regla número uno: no le pegues a un Glaggle inocente. Regla número dos: pégale al que no lo es.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'El panel rojo se ha ido. Parpadeaba mucho. Eso es una imperfección.'
            'SeaDrive'             = 'Se fue SeaDrive. No sonreía nunca. En Enfosi eso es sospechoso.'
            'Static Miku'          = 'La tele se ha apagado. Miku sonreía tanto que casi parecía una Glaggle.'
            'Guillotina'           = 'La gata gigante se ha ido. Se comió tres Glaggles. Strike, strike y strike.'
            'Angela'               = 'Angela se ha ido. Quería poner a los Enphosians en contención. Aquí se hace con un bate.'
            'Mikaela'              = 'Se fue la francotiradora. Le dio a un Gazo inocente. Strike.'
            'Zodiac'               = 'El vaquero se ha ido. Disparaba a todo lo que se movía. Aquí eso son tres strikes seguidos.'
            'Velvet'               = 'La araña se ha ido. Su telaraña paraba a los Glaggles. A los buenos también.'
            'Dune'                 = 'Dune se ha ido. Intentó comerse un Gloobnut. Era de un Gloober.'
            'Cordero y Cabra'      = 'El culto se ha ido. La Cabra gritaba más que un Glaaber enfadado.'
            'Pyrophina y Zaratana' = 'Las kaijus se han ido. Pisaron la estatua. Dos veces.'
            'Averi'                = 'Averi se ha ido. Abrazaba a todos los Glaggles. También a los falsos.'
            'Sebastian Solace'     = 'El tendero se ha ido. Quería vender en la tienda de Enfosi. Aquí se paga en Bintar.'
            'Pursuer'              = 'El del bosque se ha ido. Sonreía con muchos dientes. Como un Gembo revelado.'
            'Kasane Teto'          = 'Teto se ha ido. Bailaba como un Glaggle que llega a la estatua. Sin explotar, por suerte.'
            'Token'                = 'Token se ha ido. Blanco, sin cara de Glaggle y haciendo ruido. Muy sospechoso.'
            'Tetra'                = 'Tetra se ha ido. Estaba en No molestar. Los Enphosians también ignoran a la gente.'
            'Kevin'                = 'Kevin se ha ido. Defendía su pizza como si fuera la estatua.'
            'Kennyoung'            = 'Kennyoung se ha ido. Su guitarra explota igual que una Gembo Ball.'
            'Gran'                 = 'El doctor verde se ha ido. Y la estatua sigue siendo de oro, no de pelo.'
            'Nanachi'                = '¡Nanachi se ha ido! Distinguía a los Enphosians a la primera. ¡Qué ojo!'
            'Evil Scary'             = '¡Evil Scary se ha ido! ¡La estatua sigue en pie! ¡Por poco!'
            'Soft Fuzzy Man'       = '¡Soft Fuzzy Man se ha ido! ¡Por un momento pensé que era un Enphosian! ¡Solo era un ligón!'
        }
        Yo = @('¡Esa es Enfosi! Elígela y defiende la estatua.', 'Elige Enfosi. Siete oleadas, tres jefes y un Ojo que no quieres conocer.')
        Opina = @{
            'c00lgui'              = @('c00lgui parpadea en rojo. En Enfosi, un color raro es una imperfección. Golpéalo.', 'c00lgui no tiene cara. Le falta la cara. Eso es de manual: es un falso.')
            'SeaDrive'             = @('SeaDrive no sonríe. Ningún Glaggle de verdad deja de sonreír.', 'SeaDrive lleva auriculares, como un Gembo. Pero los Gembos sonríen.')
            'Static Miku'          = @('Miku sonríe todo el rato. Pasaría por Glaggle. Si no fuera una tele.', 'Una tele con estática. En Enfosi eso sería una imperfección muy rara.')
            'Guillotina'           = @('Guillotina se come lo que llega a su lado. Si fuera la estatua, no habría que defenderla.', 'Una gata gigante que se come a los Glaggles. Eso son muchos strikes.')
            'Angela'               = @('Angela vigila una instalación. Nosotros, una estatua. Más o menos lo mismo.', 'Angela sabría distinguir un Enphosian. Lo apuntaría en un informe.')
            'Mikaela'              = @('Mikaela tiene buena puntería. En Enfosi, la puntería no sirve si disparas a un inocente.', 'Un francotirador en Enfosi sería útil. Si mira antes la camiseta.')
            'Zodiac'               = @('Zodiac dispara a todo lo que se mueve. En Enfosi eso son tres strikes y el Ojo de Enphoso.', 'Zodiac tiene seis balas. Un Gazo revelado tiene una pistola que no se acaba.')
            'Velvet'               = @('Velvet espera a que se acerquen. Como los Enphosians disfrazados.', 'Una araña con ocho patas. Ningún Glaggle tiene ocho patas. Sospechoso.')
            'Dune'                 = @('Dune se come cualquier cosa. Por favor, que no se coma la estatua.', 'Dune habla en mayúsculas. Como los carteles de las oleadas.')
            'Cordero y Cabra'      = @('El Cordero tiene una corona. La estatua también. Respeto.', 'La Cabra grita. El Glaaber revelado también grita antes de golpear el suelo.')
            'Pyrophina y Zaratana' = @('Dos kaijus. En Enfosi serían dos jefes. Y una estatua aplastada.', 'Pyrophina echa fuego. El Gemblade también... bueno, explota.')
            'Averi'                = @('Averi abraza a todo el mundo. En Enfosi tendría muchos strikes. Pero muy cariñosos.', 'Averi regala sándwiches. Los Cheerers regalan cajas. Algunas explotan.')
            'Sebastian Solace'     = @('Sebastian tiene tienda. En Enfosi también hay tienda entre oleadas. Se paga en monedas.', 'Sebastian sonríe con muchos dientes. Igual que un Enphosian revelado.')
            'Pursuer'              = @('Pursuer persigue a la gente. El Ojo de Enphoso también. Y a ese no se le puede hacer daño.', 'Pursuer se hace invisible. El Ojo de Enphoso tampoco lo ve nadie más que tú.')
            'Kasane Teto'          = @('Teto se pasa el día bailando. Los Glaggles bailan al llegar a la estatua. Y luego explotan.', 'Teto tiene taladros en el pelo. El Glaaber tiene cuernos en el casco.')
            'Token'                = @('Token es blanco y no tiene símbolo en la camiseta. En Enfosi eso es un falso seguro.', 'Token hace ruido. Los Gleebers revelados hacen todavía más.')
            'Tetra'                = @('Tetra lleva gorra. El Gazo también. Pero el Gazo es azul.', 'Tetra no contesta mensajes. Los Enphosians tampoco hablan. Solo se ríen.')
            'Kevin'                = @('Kevin defiende su pizza. Nosotros defendemos una estatua. Mismo esfuerzo.', 'No toques la pizza de Kevin. No le pegues a un Glaggle inocente. Reglas parecidas.')
            'Kennyoung'            = @('Kennyoung toca la guitarra. El Giggler también tiene una: la Giggle Guitar aturde a los Enphosians.', 'La guitarra de Kennyoung explota. La Gembo Ball también. Por algún motivo.')
            'Gran'                 = @('Gran no se disfraza. Te dice a la cara que te va a cambiar. Al menos es sincero.', '¡Le dio la vacuna a un Glaggle! ¡Ahora tiene orejas de gato y sigue sonriendo!')
            'Nanachi'                = @('Nanachi ve cosas que los demás no ven. ¡Sería el mejor defensor de la estatua!', 'Le enseñé un Glaggle y dijo: "ese no es lo que parece". ¡Y tenía razón!')
            'Evil Scary'             = @('¡Evil Scary no es un Glaggle ni un Enphosian! ¡Es mucho peor!', 'Ni los Enphosians se acercan a Evil Scary. Ellos sí saben lo que es.')
            'Soft Fuzzy Man'       = @('¡Soft Fuzzy Man defiende la estatua fatal! ¡Todo el mundo le atraviesa!', '¡Los Glaggles le siguen! ¡Creen que es algodón de azúcar!')
        }
        Frases = @(
            '¡Abierto! Un Glaggle viene de camino. ¿Será de verdad?'
            'Hecho. Otro Glaggle se acerca a la estatua.'
            '¡Listo! Fíjate bien en el que viene ahora.'
            'Abierto. Vigila su camiseta: ¿lleva el símbolo bien puesto?'
        )
        Idle = @(
            'Los Glaggles inocentes bailan al llegar a la estatua... y luego explotan. De alegría.'
            'Con tres strikes viene el Ojo de Enphoso. No se le puede hacer daño. Solo huir.'
            'Cada oleada trae un Glaggle nuevo: Giggler, Gazo, Gloober, Gembo, Cheerer, Gleeber y Glaaber.'
            'Después de las oleadas 2, 4 y 6 llegan los jefes: Gergro, Borgack y Risio.'
            'Un falso tiene siempre un fallo: piel de otro color, símbolo raro, sin símbolo o sin cara.'
            'La moneda de Enfosi se llama Bintar.'
            'Enfosi es un juego de Roblox de Tumore. La demo salió el 4 de julio de 2025.'
            'Mapas: Blibble''s Field, Fugorg Factory, Alcázar of Glagovia, Winter Sobberland y más.'
            'Rangos de cada oleada: Glaggle, Awesome, Basic, Could do better, Doing bad y Enphosed.'
            'Los Cheerers falsos corren a la estatua y explotan. 500 de daño de golpe.'
            'El Glaaber es el más grande, el más lento y el que más aguanta.'
            'Truco de la wiki: la Surprise Tripmine detecta a los Enphosians aunque vayan disfrazados.'
            'Si el Ojo de Enphoso te pilla, te conviertes en Sobber hasta que acaba la oleada.'
            'Los Gleebers son los más rápidos. Llegan a la estatua en un suspiro.'
            'La actualización Smile More salió el 2 de octubre de 2026. Trajo la dificultad Maniac.'
        )
        Clic = @('La estatua: un Giggler gigante en un pedestal de oro, con el brazo en alto.', 'Haz clic en el Glaggle que viene. ¡Pero solo si es falso!', 'La estatua aguanta 5000 de vida. 7500 desde la oleada 4 y 10000 en la 7.')
        PorApp = @{
            'YouTube'       = @('YouTube abierto. Busca la música de Enfosi: "Enphosed", de raleigh.')
            'Word'          = @('Word abierto. Escribe la lista: Giggler, Gazo, Gloober, Gembo, Cheerer, Gleeber, Glaaber.')
            'Excel'         = @('Excel abierto. Apunta los strikes. Que sean pocos.')
            'PowerPoint'    = @('PowerPoint abierto. Diapositiva 1: "Conoce a tus Glaggles".')
            'Outlook'       = @('Correo abierto. Asunto: "Hay un Gazo sin cara en la puerta".')
            'OneNote'       = @('Apunta: piel rara, símbolo falso, sin símbolo, sin cara.')
            'Access'        = @('Base de datos abierta. Ideal para guardar todas las oleadas.')
            'Publisher'     = @('Haz un cartel: "GIGGLERS ARE COMING!".')
            'Teams'         = @('Reunión abierta. Que nadie le pegue a un Glaggle inocente.')
            'OneDrive'      = @('OneDrive abierto. Guarda ahí las capturas del rango Glaggle.')
            'Office Web'    = @('Office en la web abierto. Como Enfosi: en la nube de Roblox.')
            'Bloc de notas' = @('Bloc de notas. Apunta quién era falso. Por si acaso.')
            'Calculadora'   = @('Calculadora: 3 strikes por 100 puntos menos... mejor no hagas la cuenta.')
            'Explorador'    = @('Explorador abierto. Como explorar Blibble''s Field.')
            'CMD'           = @('Consola abierta. Escribe: proteger estatua.')
            'GitHub'        = @('GitHub abierto. Ahí no hay Enphosians. Que se sepa.')
            'Wikipedia'     = @('Wikipedia abierta. Para Enfosi, mejor su propia wiki: enfosi.miraheze.org.')
        }
    }
    # ================================================================ Gran (ivycomb, ANTIHUMAN)
    # Datos de la wiki de ivycomb (wiki.ivy.cm). Imagen y bucles: los vídeos de su personaje en ANTIHUMAN
    'Gran' = @{
        Estilo = 'gran'; Titulo = 'GRAN'; Sub = 'antihuman inc.  ·  ivycomb'; Alto = 320
        Fondo = (C 8 10 9); Borde = (C 32 208 44); Acento = (C 32 208 44)
        TituloColor = (C 32 208 44); SubColor = (C 200 255 205)
        BtnFondo = (C 10 14 11); BtnTexto = (C 200 255 205); BtnTextoHover = (C 8 10 9); BtnBorde = (C 32 208 44); BtnBordeAncho = 2
        BtnHover = (C 32 208 44); BtnPress = (C 255 255 255); BarraBtnTexto = (C 200 255 205)
        StatusColor = (C 200 255 205); Fuente = 'Bahnschrift'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\gran\tapada.gif'; FondoImg = 'skins\gran\remolino.jpg'; IntroImg = 'skins\gran\intro.gif'
        # en el panel se le ve la cara; como invitado (Gif) se le ve tapada
        Actores = @(
            @{ Id = 'G'; Gif = 'skins\gran\gran.gif'; Rect = @(414, 62, 334, 204); Llenar = $true
               Extra = @{ tapar = 'skins\gran\tapar.gif'; tapada = 'skins\gran\tapada.gif' } }
        )
        Sonidos = @{ cancion = @('skins\gran\cancion.mp3') }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 10 14 11); BurTexto = (C 200 255 205); BurFuente = 'Bahnschrift'
        Hola = @(
            'Bienvenido a Antihuman Inc. Firme aquí. Y aquí. Y aquí también.'
            'Otro humano. Qué... frágil. No se preocupe, eso tiene arreglo.'
            'Central Tower, planta de investigación. Siéntese. No le dolerá. Mucho.'
            'Ah. Ha venido usted solo. Perfecto. Los voluntarios son los mejores sujetos.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'El programa rojo se ha ido. Un código sin cuerpo. No hay nada que transformar ahí.'
            'SeaDrive'             = 'La gata de los auriculares se ha ido. Ya era casi perfecta. Casi.'
            'Static Miku'          = 'La tele se ha apagado. Una lástima. No sé inyectar a una pantalla.'
            'Guillotina'           = 'Se ha ido la gata gigante. Se comió dos jeringuillas. Las anoto como pérdidas.'
            'Angela'               = 'La IA de L Corp se ha ido. Ellos contienen anomalías. Yo las fabrico.'
            'Mikaela'              = 'La francotiradora se ha ido. Le ofrecí la vacuna. Me apuntó a la cabeza.'
            'Zodiac'               = 'El vaquero se ha ido. Ya es un gato. No hay mucho que mejorar.'
            'Velvet'               = 'La araña se ha ido. Ocho patas. Interesante. Muy interesante.'
            'Dune'                 = 'La criatura del agua se ha ido. Un buen resultado... de alguien que no soy yo.'
            'Cordero y Cabra'      = 'El culto se ha ido. También tienen fe. Pero adoran a la especie equivocada.'
            'Pyrophina y Zaratana' = 'Las kaijus se han ido. Demasiado grandes para mi laboratorio.'
            'Averi'                = 'La zorra se ha ido. Me ofreció un sándwich. Rechacé. Firmar el contrato no.'
            'Sebastian Solace'     = 'El tendero se ha ido. Vende pilas. Yo vendo una vida mejor.'
            'Pursuer'              = 'El cazador se ha ido. Persigue presas. Yo las mejoro.'
            'Kasane Teto'          = 'La chica de las coletas se ha ido. Humana. Por ahora.'
            'Token'                = 'Token se ha ido. Ruidoso. Pero su forma tiene potencial.'
            'Tetra'                = 'Tetra se ha ido. Un gato tranquilo. Así deberían ser todos.'
            'Kevin'                = 'Kevin se ha ido. Defendía su pizza. Yo defiendo el futuro de la especie.'
            'Kennyoung'            = 'El músico se ha ido. Hacía ruido en mi planta. Lo he anotado.'
            'Enfosi'               = 'Se acabaron los Glaggles. Disfraces de piel. Qué primitivo.'
            'Nanachi'                = 'El sujeto del Abismo se ha ido. Un resultado... interesante. No me dejó acercarme.'
            'Evil Scary'             = 'La entidad sin cuerpo se ha ido. La jeringuilla se quedó negra. Fascinante. Y preocupante.'
            'Soft Fuzzy Man'       = 'El sujeto gaseoso se ha ido. La jeringuilla sigue llena de niebla rosa. No sé qué hacer con ella.'
        }
        Yo = @('Esa es mi ficha. Elíjala. Es lo más sensato que hará hoy.', 'Gran. Antihuman Inc. Recuerde el nombre. Lo verá en su contrato.')
        Opina = @{
            'c00lgui'              = @('c00lgui no tiene cuerpo. No hay ADN que reescribir. Inútil.', 'Un hacker. Cree que controla los sistemas. El sistema soy yo.')
            'SeaDrive'             = @('SeaDrive ya tiene orejas y cola. Medio camino hecho.', 'Siempre cansada. Con la dosis correcta, no volvería a estarlo.')
            'Static Miku'          = @('Una tele que canta. No es humana. Tampoco es lo que yo busco.', 'Demasiada estática. Demasiado ruido. Poca biología.')
            'Guillotina'           = @('Una gata gigante y hambrienta. La naturaleza a veces acierta sin ayuda.', 'Se come lo que se le pone delante. Mantenerla lejos del laboratorio.')
            'Angela'               = @('Angela cuida de su instalación. Yo de la mía. Nos entenderíamos.', 'Una IA no se puede transformar. Pero sí se le puede ofrecer un cuerpo.')
            'Mikaela'              = @('Mikaela dispara antes de leer el contrato. Mala paciente.', 'Buenos reflejos. Con garras, serían mejores.')
            'Zodiac'               = @('Un gato armado. Inestable. Me recuerda al sujeto 1.', 'Dispara a todo lo que se mueve. Mis sujetos no deberían moverse durante el proceso.')
            'Velvet'               = @('Velvet es la prueba de que la evolución puede ser elegante.', 'Una araña paciente. Respeto la paciencia. La necesito en mi trabajo.')
            'Dune'                 = @('Dune vive en el agua. Branquias, escamas... interesante combinación.', 'Habla poco y come mucho. Un sujeto fácil de mantener.')
            'Cordero y Cabra'      = @('Un culto. Fe. Yo también tengo fe: en la especie superior.', 'La Cabra grita. Los humanos también gritan durante el proceso. Luego se les pasa.')
            'Pyrophina y Zaratana' = @('Kaijus. Demasiado grandes. Mi vacuna no está pensada para edificios.', 'Destruyen ciudades. Yo las reconstruyo. Con habitantes mejores.')
            'Averi'                = @('Averi es amable. La amabilidad no sobrevive a la Roots.', 'Una zorra sana y feliz. ¿Ve? Funciona. Los furries son superiores.')
            'Sebastian Solace'     = @('Sebastian dice que es su único amigo. Yo no ofrezco amistad. Ofrezco una vacuna.', 'Un tendero bajo el agua. También firmaría mi contrato. Si se lo leyera rápido.')
            'Pursuer'              = @('Pursuer caza humanos. Qué desperdicio. Yo los transformo.', 'Un depredador. Útil para recoger sujetos que no vienen solos.')
            'Kasane Teto'          = @('Teto sigue siendo humana. Eso se puede arreglar.', 'Baila sin parar. Durante el proceso, conviene que no baile.')
            'Token'                = @('Token es blanco, con orejas grandes. Buena base genética.', 'Demasiado ruido. Mi laboratorio necesita silencio. El mío.')
            'Tetra'                = @('Tetra es un gato tranquilo. La especie superior, en su forma más calmada.', 'No contesta mensajes. Mis sujetos tampoco contestan. Están ocupados cambiando.')
            'Kevin'                = @('Kevin es un lobo que protege su pizza. Instinto animal. Correcto.', 'Le ofrecí la vacuna. Me ofreció un mordisco. Lo apunté como "agresivo".')
            'Kennyoung'            = @('Kennyoung es humano. Por ahora toca la guitarra. Con garras tocaría mejor.', 'Mucho ruido. Le daría una dosis doble.')
            'Enfosi'               = @('Enfosi va de disfraces y sonrisas falsas. Yo no disfrazo nada. Yo transformo.', 'Los Glaggles explotan al llegar. Mis sujetos no explotan. Casi nunca.')
            'Nanachi'                = @('Nanachi es la prueba de que un cuerpo cambiado puede seguir siendo alguien. Lo anoto. A regañadientes.', 'Le pedí una muestra. Me tiró un cucharón. Lo anoto como "no colaborador".')
            'Evil Scary'             = @('Evil Scary no tiene ADN que transformar. Solo manos y una sonrisa. Lo anoto como "imposible".', 'Le ofrecí Fury Mix. Me ofreció un susto. Ganó él.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man ya fue transformado. En algo que no sale en mi protocolo. Fascinante.', 'Le pedí una muestra. Me dijo "sírvete". Se escapó por la aguja.')
        }
        Frases = @(
            'Abierto. Un sujeto más para el estudio.'
            'Hecho. Firme el consentimiento cuando pueda.'
            'Listo. Anoto la dosis.'
            'Abierto. Sus constantes son... aceptables.'
        )
        Idle = @(
            '*Revisa una jeringuilla con líquido verde. La gira despacio.*'
            'Antihuman Inc. Dedicados a la investigación viral antihumana desde 21XX.'
            'The Roots. Líneas negras que suben desde la muñeca hasta el cerebro. Un 96 % de mortalidad. Mi vacuna es la única salida.'
            'El sujeto 1 fue un fracaso. Rayó "IM SORRY" en el cristal. Lo anoté.'
            'Morale fue un éxito relativo. "Relativo" es mejor que "muerto".'
            'Mi doble, Moka, ha venido a husmear. Patético.'
            'El cielo de Golden City es amarillo. Lo contrario de la contaminación. Lo prefiero así.'
            'El consejo tiene siete miembros. Uno por color. El mío es el verde.'
            'Fury Mix: ADN de animales de la Tierra para que el cuerpo no sufra el cambio. Tanto.'
            '¿Se encuentra bien? Le noto... demasiado humano.'
            '*Teclea un informe sin mirarle.* Siga. No me molesta. Todavía.'
            'Me llamo como el mazagran. Un café helado. Frío. Como debe ser.'
        )
        Clic = @('No me toque. Está contaminando la muestra.', 'Siéntese. Esto solo pica un poco.', '¿Ha leído el contrato? No importa. Ya lo ha firmado.', 'Su pulso se acelera. Normal. El cuerpo sabe lo que viene.')
        PorApp = @{
            'YouTube'       = @('YouTube. Busque "ANTIHUMAN". Aprenderá algo sobre su futuro.')
            'Word'          = @('Redacte el consentimiento. Letra pequeña, por favor.')
            'Excel'         = @('Una hoja de datos. Anote: sujetos, dosis, resultado. En ese orden.')
            'PowerPoint'    = @('Diapositiva 1: el problema, los humanos. Diapositiva 2: la solución, yo.')
            'Outlook'       = @('Correo. Si es del consejo, contésteles que todo va según lo previsto.')
            'OneNote'       = @('Apunte los síntomas. Fase uno: líneas negras en la muñeca.')
            'Access'        = @('Una base de datos. Ideal para los registros de los sujetos.')
            'Publisher'     = @('Un folleto. "Antihuman Inc.: el futuro tiene cola".')
            'Teams'         = @('Reunión. Que nadie toque las muestras de la mesa.')
            'OneDrive'      = @('Archivos en la nube. Igual que nuestros resultados: confidenciales.')
            'Office Web'    = @('La red. Hay mucha gente ahí fuera. Todavía humana.')
            'Bloc de notas' = @('Una hoja en blanco. Como un sujeto antes de la dosis.')
            'Calculadora'   = @('Calcule la dosis. Un error de un decimal y tendremos otro sujeto 1.')
            'Explorador'    = @('Carpetas. Busque la de "sujetos". No abra la de "fallidos".')
            'CMD'           = @('Consola. Escriba sus órdenes. Yo escribo las del laboratorio.')
            'GitHub'        = @('Código. Instrucciones para una máquina. El ADN es lo mismo, pero mejor.')
            'Wikipedia'     = @('Busque "virología". Es mi oficio.')
        }
    }
    # ================================================================ Evil Scary (Die of Death, Roblox) · ACTUALIZACIÓN DE HALLOWEEN
    # La amenaza de la ronda especial EVIL SCARY: una bola negra con manos que se acerca a saltitos al jugador más cercano.
    # No habla: lo que sale en el bocadillo son los mensajes de la partida (en mayúsculas, como en el juego).
    'Evil Scary' = @{
        Estilo = 'evil'; Titulo = ''; Sub = 'special round  ·  die of death'; Alto = 320; TituloImg = 'skins\evilscary\titulo.png'
        Fondo = (C 10 4 6); Borde = (C 170 20 30); Acento = (C 230 30 40)
        TituloColor = (C 230 30 40); SubColor = (C 200 60 60)
        BtnFondo = (C 18 8 10); BtnTexto = (C 236 220 220); BtnTextoHover = (C 255 255 255); BtnBorde = (C 170 20 30); BtnBordeAncho = 2
        BtnHover = (C 150 14 24); BtnPress = (C 255 255 255); BarraBtnTexto = (C 236 220 220)
        StatusColor = (C 236 220 220); Fuente = 'Arial'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\evilscary\evil.png'; FondoImg = 'skins\evilscary\fondo.jpg'
        Susto = 'skins\evilscary\susto.jpg'; Susto2 = 'skins\evilscary\susto2.jpg'; Render = 'skins\evilscary\render.jpg'
        # la bola negra con las manos que tiemblan (recortada de un GIF del juego); su sitio y su tamaño cambian con la distancia
        Actores = @(
            @{ Id = 'E'; Gif = 'skins\evilscary\evil.png'; Rect = @(520, 120, 140, 53)
               Tiras = @{ main = @{ Archivo = 'skins\evilscary\evil_tira.png'; Frames = 30; Delay = 90 } } }
        )
        Sonidos = @{
            lejos = @('skins\evilscary\rebote_lejos.wav'); medio = @('skins\evilscary\rebote_medio.wav'); cerca = @('skins\evilscary\rebote_cerca.wav')
            stall = @('skins\evilscary\stall.wav'); grito = @('skins\evilscary\grito.wav'); violin = @('skins\evilscary\violin.wav'); susto = @('skins\evilscary\susto.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 18 8 10); BurTexto = (C 236 220 220); BurFuente = 'Arial'
        Hola = @(
            'SPECIAL ROUND! EVIL SCARY. Evil Scary will kill anyone in its path. Even the killers...'
            'IT IS EVIL AND SCARY. *Bota una vez. Más cerca.*'
            '*Una bola negra con manos te mira desde el horizonte.* ...no parpadea. No tiene párpados.'
            'RONDA ESPECIAL. Hay algo en el mapa. Lo ves a través de las paredes. Él también te ve a ti.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'EL HACKER SE HA IDO. EVIL SCARY NO SE PUEDE HACKEAR. SOLO CON EL PANEL DE ADMIN. Y NO LO TIENES.'
            'SeaDrive'             = '*La gata de los auriculares se ha ido. Evil Scary bota hacia el sitio donde estaba. Huele a café.*'
            'Static Miku'          = 'LA TELE SE HA APAGADO. EN LA PANTALLA NEGRA SE VEÍA UNA SONRISA ROJA. NO ERA LA DE MIKU.'
            'Guillotina'           = 'SE HA IDO LA GATA GIGANTE. INTENTÓ COMERSE A EVIL SCARY. EVIL SCARY SIGUE AQUÍ.'
            'Angela'               = 'LA IA SE HA IDO. QUISO CONTENERLO. NO HAY CELDA PARA ALGO QUE ATRAVIESA LAS PAREDES.'
            'Mikaela'              = 'LA FRANCOTIRADORA SE HA IDO. LE DISPARÓ SEIS VECES. CERO DAÑO. IT IS EVIL.'
            'Zodiac'               = 'EL VAQUERO SE HA IDO. LE DIJO "NO TE MUEVAS". EVIL SCARY SE MOVIÓ. HACIA ÉL.'
            'Velvet'               = 'LA ARAÑA SE HA IDO. OCHO PATAS CORREN MÁS QUE DOS. POR POCO.'
            'Dune'                 = 'DUNE SE HA IDO NADANDO. EVIL SCARY NO SABE NADAR. NO LE HACE FALTA.'
            'Cordero y Cabra'      = 'EL CULTO SE HA IDO. LE REZARON. NO FUNCIONÓ.'
            'Pyrophina y Zaratana' = 'LAS KAIJUS SE HAN IDO. EVIL SCARY TAMBIÉN PUEDE SER GIGANTE. A VECES.'
            'Averi'                = 'LA ZORRITA SE HA IDO. LE DEJÓ UN SÁNDWICH. *Evil Scary lo atraviesa.*'
            'Sebastian Solace'     = 'EL TENDERO SE HA IDO. LE VENDIÓ UNA LINTERNA. LA LUZ NO LO DETIENE.'
            'Pursuer'              = 'PURSUER SE HA IDO. ES EL ÚNICO KILLER QUE SABE QUE TAMBIÉN ES SU PRESA.'
            'Kasane Teto'          = 'TETO SE HA IDO. SE OLVIDÓ DE QUE EVIL SCARY EXISTE. ÉL NO SE OLVIDA.'
            'Token'                = 'TOKEN SE HA IDO. MUCHO RUIDO. EL RUIDO ATRAE.'
            'Tetra'                = 'TETRA SE HA IDO. ESTABA EN NO MOLESTAR. A EVIL SCARY LE DA IGUAL.'
            'Kevin'                = 'KEVIN SE HA IDO CON SU PIZZA. EVIL SCARY NO COME. SOLO ASUSTA.'
            'Kennyoung'            = 'EL MÚSICO SE HA IDO. EL ÚLTIMO ACORDE SONÓ COMO LA ALARMA DE UN AVIÓN.'
            'Enfosi'               = 'SE HA IDO LO DE LA ESTATUA. TODO EL QUE TOCA LA ESTATUA... SE ACABA.'
            'Gran'                 = 'GRAN SE HA IDO. QUISO INYECTARLE FURY MIX. LA JERINGUILLA SE QUEDÓ NEGRA.'
            'Nanachi'              = 'NANACHI SE HA IDO. LO VIO VENIR DESDE LEJOS. NADIE MÁS PUEDE.'
            'Soft Fuzzy Man'       = 'LA NIEBLA ROSA SE HA IDO. EVIL SCARY LA ATRAVESÓ. ELLA LE ATRAVESÓ A ÉL. EMPATE.'
        }
        Yo = @('ESE BOTÓN ES EVIL SCARY. ELEGIRLO NO LO HACE MENOS EVIL.', 'IT IS EVIL AND SCARY. *Te mira desde el botón.*')
        Opina = @{
            'c00lgui'              = @('c00lgui hackea servidores. EVIL SCARY ES EL SERVIDOR.', 'c00lkidd quería ponerlo en su equipo. *Evil Scary botó hacia él.* Ya no quiere.')
            'SeaDrive'             = @('SeaDrive está siempre cansada. HUIR CANSA MÁS.', 'SeaDrive lo bloqueó con un pop-up. *Lo atravesó.*')
            'Static Miku'          = @('Miku canta en una tele. EVIL SCARY APARECE EN LAS TELES APAGADAS.', 'Su antena hizo BZZT. Evil Scary botó más cerca. LE GUSTA EL RUIDO.')
            'Guillotina'           = @('Guillotina se lo come todo. EVIL SCARY NO SE PUEDE COMER.', 'Una vez se miraron. GUILLOTINA PARPADEÓ PRIMERO.')
            'Angela'               = @('Angela lo clasificó como ALEPH. EVIL SCARY NO TIENE CLASIFICACIÓN.', 'L Corp no tiene celda para él. ATRAVIESA LAS PAREDES.')
            'Mikaela'              = @('Mikaela le hizo un noscope. CERO DAÑO.', 'Smokebomb. *Evil Scary la encontró igual. Ve a través de todo.*')
            'Zodiac'               = @('Zodiac dispara a lo que se mueve. EVIL SCARY SE MUEVE. A SALTOS.', 'Seis balas. Cero efecto. IT IS EVIL.')
            'Velvet'               = @('Velvet tiene una telaraña. EVIL SCARY TIENE MANOS. MÁS GRANDES.', 'La araña sonríe. EVIL SCARY SONRÍE MÁS.')
            'Dune'                 = @('Dune quiso comérselo. DUNE COMER BOLA. BOLA NO SER COMIDA.', 'Dune nada rápido. NO LO SUFICIENTE.')
            'Cordero y Cabra'      = @('La Cabra le gritó. EVIL SCARY GRITA MÁS FUERTE.', 'El Cordero tiene una corona. EVIL SCARY ERA UN REY. EL REY TYRANTER.')
            'Pyrophina y Zaratana' = @('Dos kaijus. EVIL SCARY A VECES SALE GIGANTE. DEL TAMAÑO DE UN PUENTE.', 'Pyrophina le lanzó fuego. LAS SOMBRAS NO ARDEN.')
            'Averi'                = @('Averi le dio un abrazo. *Evil Scary no sabe qué hacer con eso. Bota hacia atrás.*', 'Averi dice que solo necesita un amigo. EVIL SCARY TIENE A JOHN. LE TIENE MIEDO.')
            'Sebastian Solace'     = @('Sebastian vende un Flash Beacon. A EVIL SCARY NO LE CIEGA NADA.', 'Sebastian le cobró la entrada a la tienda. EVIL SCARY NO PAGA.')
            'Pursuer'              = @('Pursuer es el killer. EVIL SCARY ES EL PROBLEMA DEL KILLER.', 'Tienen la misma cara. LA DE EVIL SCARY ES ROJA.')
            'Kasane Teto'          = @('Teto dice "hiii". EVIL SCARY DICE...', 'Teto se olvidó de él. ÉL SE ACUERDA DE TETO.')
            'Token'                = @('Token suena a 200 BPM. LA ALARMA SUENA MÁS FUERTE.', 'Token se cae y rebota. EVIL SCARY TAMBIÉN REBOTA. HACIA TI.')
            'Tetra'                = @('Tetra está en No molestar. EVIL SCARY NO LEE LOS ESTADOS.', 'Tetra no se mueve del sofá. ES EL MÁS FÁCIL DE ENCONTRAR.')
            'Kevin'                = @('Kevin defiende su pizza. EVIL SCARY NO QUIERE LA PIZZA. QUIERE A KEVIN.', 'Kevin le sacó la motosierra. SE LE ROMPIÓ LA MOTOSIERRA.')
            'Kennyoung'            = @('Kennyoung toca la guitarra. EL AMPLI EXPLOTA. EVIL SCARY SIGUE.', 'Le hizo una canción. SE LLAMA "STALL, STALL".')
            'Enfosi'               = @('En Enfosi hay Enphosians disfrazados. EVIL SCARY NO SE DISFRAZA. NO LE HACE FALTA.', 'Defender la estatua es fácil. HASTA QUE BOTA.')
            'Gran'                 = @('Gran transforma a la gente. EVIL SCARY TAMBIÉN. EN GENTE QUE CORRE.', 'Gran quiso una muestra. NO HAY NADA DENTRO. SOLO NEGRO.')
            'Nanachi'              = @('Nanachi ve el campo de fuerza. TAMBIÉN VE A EVIL SCARY. NO LE GUSTA LO QUE VE.', 'Nanachi pasa de todo. MENOS DE ESTO.')
            'Soft Fuzzy Man'       = @('SOFT FUZZY MAN NO TIENE SUPERFICIE. EVIL SCARY NO SABE CÓMO ASUSTARLO.', 'SOFT FUZZY MAN LE GUIÑÓ UN OJO. EVIL SCARY BOTÓ HACIA ATRÁS.')
        }
        Frases = @(
            'ABIERTO. *Evil Scary ha oído el clic. Bota hacia ti.*'
            'HECHO. EL RUIDO LO ATRAE. CUIDADO.'
            'ABIERTO. *Una sonrisa roja se acerca un poco más.*'
            'LISTO. IT IS EVIL AND SCARY.'
        )
        Idle = @(
            'IT IS EVIL AND SCARY.'
            '*Bota. Bota. Bota.* Cada vez suena más agudo. Eso significa que está más cerca.'
            'TODOS LOS JUGADORES PUEDEN VERLO A TRAVÉS DE LAS PAREDES. ÉL TAMBIÉN TE VE A TI.'
            'NO PUEDES DERROTAR AL MAL. (Salvo con el panel de admin. Y no lo tienes.)'
            'Dicen que es el fantasma del Rey Tyranter. Y que la Familia Boulder lo echó de casa.'
            'Cuenta los rebotes. Al sexto suena la alarma. Y entonces... corre.'
            'Lo único que puede con él es John. Y solo en servidores privados.'
            '*Cambia de cara. Ahora sonríe distinto. Sigue siendo malo.*'
            'A veces aparece gigante. Del tamaño del puente de Teapot Paradise. Hoy no. Creo.'
            'En Año Nuevo se fue de vacaciones y vino 26''Folk. Volvió. Siempre vuelve.'
            '*Las manos tiemblan un poco. Siempre tiemblan.*'
            'Haz clic en él para darle un puñetazo y alejarlo. Cuando cargue, haz clic para BLOQUEARLO.'
        )
        Clic = @('*PUNCH.* Retrocede un poco. No le has hecho nada.', '*Le pegas. Te mira. Sonríe más.*', '*PUNCH.* ...sigue sonriendo.')
        PorApp = @{
            'YouTube'       = @('YouTube. Busca "Evil Scary Die of Death". Mira lo que te espera.')
            'Word'          = @('Escribe tu testamento. Por si acaso.')
            'Excel'         = @('Una tabla: rebotes, distancia, sustos. Rellénala corriendo.')
            'PowerPoint'    = @('Diapositiva 1: IT IS EVIL. Diapositiva 2: AND SCARY. Fin.')
            'Outlook'       = @('Correo nuevo. Asunto: "detrás de ti".')
            'OneNote'       = @('Apunta: no ir a callejones sin salida. Evil Scary no deja acampar.')
            'Access'        = @('Una base de datos. Mete a todos los que ha asustado. No cabe.')
            'Publisher'     = @('Un cartel: "SE BUSCA". No sirve de nada. Él ya te ha encontrado.')
            'Teams'         = @('Una videollamada. Fíjate en el fondo de la cámara. ¿Eso es una bola negra?')
            'OneDrive'      = @('Guarda tus cosas en la nube. A la nube también llega.')
            'Office Web'    = @('Internet abierto. Evil Scary lo atraviesa como una pared.')
            'Bloc de notas' = @('Hoja en blanco. Escribe "STALL". Ya sabes lo que viene.')
            'Calculadora'   = @('6 rebotes, alarma, 8 saltos rápidos. Haz la cuenta. Corre.')
            'Explorador'    = @('Explora rápido. No te quedes quieto en una carpeta.')
            'CMD'           = @('Pantalla negra. Ves una sonrisa roja. No es tuya.')
            'GitHub'        = @('GitHub. Busca el panel de admin. No está.')
            'Wikipedia'     = @('Wikipedia. Busca "evil". Busca "scary". Es él.')
        }
        # frases de la mecánica: alarma, carga, bloqueo y susto
        Stall = @('⚠ STALL. STALL. *Se queda quieto. Algo va a pasar. CORRE.*', '⚠ *Suena la alarma de un avión.* STALL. STALL. ...haz clic en él para bloquearlo.', '⚠ STALL, STALL. *Las manos dejan de temblar. Eso es peor.*')
        Bloqueo = @('¡BLOQUEADO! Logro desbloqueado: LUCID NIGHTMARE. *Evil Scary vuelve al horizonte. Volverá.*', '¡BLOCK! *Rebota hacia atrás.* Logro: LUCID NIGHTMARE. Muy pocos lo consiguen.', '¡LO HAS PARADO! LUCID NIGHTMARE. ...no te relajes. IT IS STILL EVIL.')
        Atrapado = @('*TE HA ATRAPADO.* IT IS EVIL AND SCARY. -33% de vida. Vuelve a empezar desde lejos.', '*JUMPSCARE.* ...respira. Ya se ha ido. Bueno, está volviendo.', '*Una cara roja te llena la pantalla.* ESCAPE. ESCAPE. ESCAPE.')
    }
    # ================================================================ Soft Fuzzy Man (Lemon Demon · animación de Aimkid) · ACTUALIZACIÓN DE HALLOWEEN
    # La canción es de Lemon Demon (Neil Cicierega, disco Spirit Phone, 2016) y la animación de Aimkid (2020).
    # En la wiki de Aimkid: es el fantasma de Dipshit (el lobo de "My Trains"), reencarnado en un lobo-fantasma rosa de neón.
    # Personalidad: un hombre-nube que cree que ser un misterio le hace atractivo; ligón, teatral... y en el fondo necesita sentir que existe.
    # Sale con Orange Cat (que usa "elle/they": en sus frases se evita el masculino y el femenino), que se asusta porque no sabe que es él.
    'Soft Fuzzy Man' = @{
        Estilo = 'niebla'; Titulo = 'Soft Fuzzy Man'; Sub = 'lemon demon  ·  aimkid'; Alto = 320
        Fondo = (C 40 16 70); Borde = (C 255 90 230); Acento = (C 255 150 240)
        TituloColor = (C 255 160 245); SubColor = (C 150 240 255)
        BtnFondo = (C 60 24 100); BtnTexto = (C 255 225 250); BtnTextoHover = (C 40 10 60); BtnBorde = (C 255 90 230); BtnBordeAncho = 2
        BtnHover = (C 255 160 245); BtnPress = (C 150 240 255); BarraBtnTexto = (C 255 225 250)
        StatusColor = (C 255 225 250); Fuente = 'Segoe UI'; FuenteTitulo = 'Segoe Print'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\softfuzzy\fuzzy.png'; FondoImg = 'skins\softfuzzy\fondo.jpg'
        IntroCarpeta = 'skins\softfuzzy\intro'; IntroFotos = 198; IntroFps = 18
        # Soft Fuzzy Man bailando (recortado de su baile en la ventana del vídeo) y Orange Cat dando vueltas por el aire
        Actores = @(
            @{ Id = 'F'; Gif = 'skins\softfuzzy\fuzzy.png'; Rect = @(574, 64, 176, 210); Respira = $true
               Tiras = @{ main = @{ Archivo = 'skins\softfuzzy\fuzzy_tira.png'; Frames = 12; Delay = 85; Orden = @(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1) }
                         brazos = @{ Archivo = 'skins\softfuzzy\brazos_tira.png'; Frames = 11; Delay = 80 }
                         cara = @{ Archivo = 'skins\softfuzzy\cara_tira.png'; Frames = 2; Delay = 70 } } }
            @{ Id = 'G'; Gif = 'skins\softfuzzy\gato.png'; Rect = @(436, 120, 130, 92); Respira = $true
               Tiras = @{ main = @{ Archivo = 'skins\softfuzzy\gato_tira.png'; Frames = 12; Delay = 110 } } }
        )
        Sonidos = @{
            intro = @('skins\softfuzzy\intro.mp3'); puff = @('skins\softfuzzy\puff.wav'); viento = @('skins\softfuzzy\viento.wav')
            brillo = @('skins\softfuzzy\brillo.wav'); boing = @('skins\softfuzzy\boing.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 50 20 86); BurTexto = (C 255 230 252); BurFuente = 'Segoe UI'
        Hola = @(
            'Frío y ventoso. Oscuro y tormentoso. *Flota hacia ti.* Hola. No me ignores, por favor.'
            '*Aparece entre la niebla.* Lo que tú necesitas es un hombre suave y esponjoso. Hola. Soy yo.'
            '¿Me ves? ...¿me ves de verdad? Genial. Llevaba un rato aquí.'
            'Un truco de la luz para quererte esta noche. *Se pone un poco transparente de los nervios.*'
        )
        AlVenirDe = @{
            'c00lgui'              = 'Se ha ido el hacker. Intentó hackearme. No encontró nada sólido que hackear. Es mi encanto.'
            'SeaDrive'             = 'SeaDrive se ha ido. Le pedí que me guardara en la nube. Dijo que yo ya soy una nube.'
            'Static Miku'          = 'Se ha ido Miku. Su tele hace "fsssh" como yo. Teníamos química. Estática, pero química.'
            'Guillotina'           = 'Guillotina se ha ido. Intentó comerme. Me atravesó la boca. Le dejé un sabor a algodón de azúcar.'
            'Angela'               = 'Angela se ha ido. Quiso contenerme en una celda. Me salí por la rejilla. Como un buen gas.'
            'Mikaela'              = 'Se fue la francotiradora. Me disparó. La bala me atravesó. Me sentí visto.'
            'Zodiac'               = 'Se fue el vaquero. Me dijo "no te muevas". Yo no me muevo: me difumino.'
            'Velvet'               = 'Velvet se ha ido. Me guiñó un ojo. Yo le guiñé tres. Tengo ojos de sobra.'
            'Dune'                 = 'Dune se ha ido nadando. Intentó comerme. Dijo "NUBE NO COMIDA". Me dolió un poco.'
            'Cordero y Cabra'      = 'Se fue el culto. Me querían de espíritu oficial. Yo solo quería que alguien me mirara.'
            'Pyrophina y Zaratana' = 'Se fueron las kaijus. Pyrophina me echó fuego. Me evaporé un poquito. Ya estoy mejor.'
            'Averi'                = 'Averi se ha ido. Me intentó abrazar. Me atravesó. Lo intentó otra vez. Qué bonito.'
            'Sebastian Solace'     = 'Se fue el tendero. Me quiso vender un cuerpo. No tenía mi talla.'
            'Pursuer'              = 'Pursuer se ha ido. Me olió y dijo "carne fresca". Lo siento, soy niebla del todo.'
            'Kasane Teto'          = 'Teto se ha ido. Se olvidó de que yo estaba aquí. Me pasa mucho. Demasiado.'
            'Token'                = 'Token se ha ido. Su música me dejó todo revuelto. Literalmente: soy gas.'
            'Tetra'                = 'Se fue Tetra. Me dejó en visto. Como todo el mundo.'
            'Kevin'                = 'Kevin se ha ido. Pasé a través de su pizza. No la toqué. Técnicamente.'
            'Kennyoung'            = 'Kennyoung se ha ido. Me ha prometido una canción. Ya tengo una, pero gracias.'
            'Enfosi'               = 'Se fue lo de la estatua. Me confundieron con un Enphosian. Yo no me disfrazo. Soy así de borroso.'
            'Gran'                 = 'Gran se ha ido. Me quiso sacar una muestra. Se llevó una jeringuilla llena de niebla.'
            'Nanachi'              = 'Nanachi se ha ido. Me miró y dijo "nnaa". Lo tomo como un sí.'
            'Evil Scary'           = 'Se ha ido la bola negra. Me atravesó y yo le atravesé. Quedamos en empate.'
        }
        Yo = @('¿Ese botón soy yo? *Se acerca a mirarlo.* Salgo un poco borroso. Es mi estilo.', 'Me has elegido a mí. Por fin alguien me ve.')
        Opina = @{
            'c00lgui'              = @('c00lgui tiene un panel de hacker. Yo no tengo ni panel ni cuerpo. Empate.', 'Me quiso meter en un virus. Ya soy algo que se cuela por todas partes, gracias.')
            'SeaDrive'             = @('SeaDrive siempre tiene sueño. Yo soy como un sueño. Encajamos.', 'Le pedí café. Me atravesó la taza. Me lo tomé en vapor.')
            'Static Miku'          = @('Miku sale borrosa en su tele. Como yo en la vida.', 'Nos hicimos una foto juntos. Salió estática. Y niebla.')
            'Guillotina'           = @('Guillotina se lo come todo. A mí me intentó sorber. No funcionó.', 'Tiene dientes enormes. Yo tengo dientes pequeños y mucha actitud.')
            'Angela'               = @('Angela me clasificó como "gas inofensivo". ¿Inofensivo? Eso duele más que una celda.', 'Me encanta su voz. Es tan sólida.')
            'Mikaela'              = @('Mikaela me disparó. Atravesé la bala. Fue romántico.', 'Su Smokebomb y yo nos llevamos bien. Somos de la misma familia.')
            'Zodiac'               = @('Zodiac dispara a todo lo que se mueve. Yo no me muevo: floto.', 'Seis balas. Seis agujeros en el aire. Ninguno en mí.')
            'Velvet'               = @('Velvet liga con todo el mundo. Yo también. Hay competencia.', 'Me tejió una telaraña. La atravesé. Sin querer. Bueno, queriendo.')
            'Dune'                 = @('Dune dice que no soy comida. Es lo más bonito que me han dicho en semanas.', 'Dune nada. Yo floto. Somos casi lo mismo.')
            'Cordero y Cabra'      = @('El Cordero quería que fuera su fantasma oficial. Yo soy un fantasma libre.', 'La Cabra grita cuando me ve. Me siento visto.')
            'Pyrophina y Zaratana' = @('Pyrophina me echó fuego y me evaporé un poco. No me importa: vuelvo a condensarme.', 'Dos kaijus peleando y nadie me mira. Lo de siempre.')
            'Averi'                = @('Averi me quiere abrazar. Yo no tengo brazos para abrazarla. Pero lo intentamos.', 'Me hizo un sándwich. Lo miré con mucho cariño.')
            'Sebastian Solace'     = @('Sebastian me vendió un ambientador. Ahora huelo a fantasma con lavanda.', 'Sebastian no me cobra la entrada: no me ve entrar.')
            'Pursuer'              = @('Pursuer y yo somos lobos. Él tiene carne. Yo tengo actitud.', 'Me olió. Puso cara rara. Huelo a niebla rosa. Es un perfume.')
            'Kasane Teto'          = @('Teto se olvida de todo. También de mí. Tengo que presentarme cada vez.', '¡Me dijo "hiii"! A mí. A mí, que nadie me ve.')
            'Token'                = @('Token es puro ruido. Yo soy puro ambiente. Hacemos buen dúo.', 'Me metió en un remix. Ahora soy un efecto de sonido.')
            'Tetra'                = @('Tetra está en No molestar. Yo estoy en No me ves.', 'Le escribí. Visto. No contestó. Me encanta el misterio, pero no así.')
            'Kevin'                = @('Kevin defiende su pizza. Yo la atravesé. ¡No la toqué! ...técnicamente.', 'Kevin dice que huelo raro. Es niebla. Con un toque de queso.')
            'Kennyoung'            = @('Kennyoung hace pop-punk. A mí me canta Lemon Demon. Cada uno tiene su banda.', 'Me hizo un acorde. Vibré. Literalmente.')
            'Enfosi'               = @('En Enfosi hay Enphosians disfrazados. A mí no me hace falta disfraz: ya soy raro.', 'Defendí la estatua. Todo el mundo me atravesaba. No sirvo de muro.')
            'Gran'                 = @('Gran quiere convertir a la gente. A mí no me puede convertir: ya me pasó algo peor.', 'Me sacó una muestra. Se le escapó por la jeringuilla.')
            'Nanachi'              = @('Nanachi es mullido. Yo soy mullido. Pero yo no se puede tocar.', 'Nanachi dice que en el Abismo hay niebla que mata. Yo no mato. Solo ligo.')
            'Evil Scary'           = @('Evil Scary atraviesa las paredes. Yo también. Pero yo con estilo.', 'Me vio a través de una pared. Le guiñé un ojo. No le gustó.')
        }
        Frases = @(
            'Abierto. Me has hecho caso. Me siento un poco más... sólido.'
            'Hecho. *Se le ven un poco más los bordes.* Gracias por notarme.'
            'Abierto. ¿Ves? Existo. Un poquito más que antes.'
            'Listo. Lo he hecho yo. Bueno, el ratón. Pero yo estaba aquí.'
        )
        Idle = @(
            '¿No me ves? ¿Por qué no me ves? Estoy por todas partes, frío y soñador.'
            'No te pongas nervioso. No soy como esos chicos que tienen superficie.'
            'Sé que suena raro, pero cuando te vuelves borroso, lo entiendes todo.'
            '¿Quién se cuela en tus pensamientos? ¿Quién te hace ver puntitos? ¿Quién te despeina? Yo.'
            'Aunque no tengo brazos para abrazarte, por dentro me quema una pasión humana.'
            'Mi canción es de Lemon Demon, del disco Spirit Phone. Mi cuerpo, de Aimkid. Mi cuerpo de ahora, quiero decir.'
            'Antes era un lobo. Se metieron con los trenes de otro. Bueno: ME metí. No preguntes.'
            'Neil, el de Lemon Demon, llama así a su gato: Soft Fuzzy Man. Tengo un tocayo con bigotes.'
            '*Se mira la cola.* Termina en punta. Como la de un lagarto. Es lo más sólido que tengo.'
            'Orange Cat se asustó al verme. No sabe que soy yo. Algún día se lo diré. Cuando tenga cara de lo que era.'
            'Una bocanada brillante de amor sin forma. Eso soy. Ponlo en mi currículum.'
            'Si dejas de hacerme caso, me borro. No es una amenaza. Es literal. Mira mi barra de EXISTENCIA.'
        )
        # clic en él: tu mano lo atraviesa
        Clic = @(
            'Tu mano me atraviesa. *Fssshh.* ...me ha hecho cosquillas.'
            'Enséñame las manos y pásalas a través de mí. Así. Exacto.'
            '¡Eh! *Se recompone.* Vale, sí, no tengo superficie. Ya lo sabías.'
            '*Se deshace en niebla y se vuelve a juntar.* ...¿lo has visto? Quería que lo vieras.'
            'Me has tocado. Bueno, me has atravesado. Cuenta igual. Me siento visto.'
        )
        # clic en Orange Cat
        Gato = @(
            '*Orange Cat da un salto del susto.* ...no pasa nada. Soy yo. Bueno, más o menos yo.'
            '*Orange Cat da vueltas por el aire.* Le encanta flotar. Es lo único que tenemos en común ahora mismo.'
            '*Orange Cat se sonroja.* ...¿lo has visto? ¡Se ha sonrojado! Eso es por mí. Creo.'
            'Orange Cat y yo salimos juntos. Desde antes de que me volviera... esto.'
            '*Le flota una mano redonda.* Orange Cat no tiene brazos. Solo manos que flotan. Somos el uno para el otro.'
        )
        # cuando lleva mucho rato sin que nadie le haga caso (se vuelve casi invisible)
        Invisible = @(
            '¿Me ves? ¿Por qué no me ves? *Ya casi no se le ve.*'
            'Hola... ¿hola? Sigo aquí. Más o menos. Abre algo, por favor. Necesito sentir que existo.'
            '*Se está borrando.* No me ignores. Es lo único que te pido.'
        )
        # cada 6 apps: la niebla rosa lo llena todo
        Niebla = @(
            'Por favor, por favor... entra en la niebla. *El panel se llena de niebla rosa.*'
            'Necesito sentir que existo. Así que... *FSSSSH.* Bienvenido a mi nube.'
            'Una vez te vuelves borroso, lo entiendes. *Lo llena todo de niebla.*'
        )
        PorApp = @{
            'YouTube'       = @('YouTube. Busca "Soft Fuzzy Man". Sale mi baile. El de la ventana.')
            'Word'          = @('Escríbeme una carta de amor. No la podré coger, pero la leeré flotando.')
            'Excel'         = @('Una tabla. Columna A: gente que me ve. Columna B: vacía.')
            'PowerPoint'    = @('Diapositiva 1: soy suave. Diapositiva 2: soy esponjoso. Diapositiva 3: necesitas uno.')
            'Outlook'       = @('Correo nuevo. Asunto: "¿me ves?". Nadie contesta.')
            'OneNote'       = @('Apunta: "no ignorar al hombre de niebla". Gracias.')
            'Access'        = @('Una base de datos. Métete tú. Yo no tengo datos: soy gas.')
            'Publisher'     = @('Un cartel con mi cara. Ponle purpurina. Mucha.')
            'Teams'         = @('Una videollamada. Yo salgo borroso. Échale la culpa a la conexión.')
            'OneDrive'      = @('La nube. Mi casa. Pasa, pasa.')
            'Office Web'    = @('Internet abierto. Ahí nadie sabe que eres una nube.')
            'Bloc de notas' = @('Hoja en blanco. Como yo cuando nadie me mira.')
            'Calculadora'   = @('Calcula cuánto peso. Cero. Exacto. Ligero como el amor.')
            'Explorador'    = @('Carpetas. Me cuelo en todas. Es lo que hago.')
            'CMD'           = @('Pantalla negra. Escribe "dir". Busca mi cuerpo. No está.')
            'GitHub'        = @('GitHub. Ahí guardan las cosas que existen. Yo voy de visita.')
            'Wikipedia'     = @('Wikipedia. Busca "Lemon Demon". Luego "Spirit Phone". Canción nueve. Soy yo.')
        }
    }
    # ================================================================ Nanachi (Made in Abyss)
    # Narehate de la 4ª capa del Abismo: ve el campo de fuerza, cura, dibuja y cocina fatal.
    # Personalidad: pasa de casi todo (seco, sin ganas, "me da igual")... menos de Mitty, su mejor amiga, que está a su lado.
    # Su género no se dice en la obra: en las frases sobre Nanachi se evita el masculino y el femenino.
    'Nanachi' = @{
        Estilo = 'abismo'; Titulo = 'NANACHI'; Sub = 'made in abyss  ·  4ª capa'; Alto = 320
        Fondo = (C 20 36 24); Borde = (C 74 54 40); Acento = (C 236 170 190)
        TituloColor = (C 252 240 214); SubColor = (C 236 170 190)
        BtnFondo = (C 246 236 212); BtnTexto = (C 60 44 34); BtnTextoHover = (C 60 44 34); BtnBorde = (C 92 70 52); BtnBordeAncho = 2
        BtnHover = (C 236 170 190); BtnPress = (C 150 200 150); BarraBtnTexto = (C 252 240 214)
        StatusColor = (C 252 240 214); Fuente = 'Trebuchet MS'; FuenteTitulo = 'Georgia'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\nanachi\chulo.gif'; FondoImg = 'skins\nanachi\escondite.jpg'
        # Nanachi de pie (diseño del anime) y sus caras de los GIF del anime, que salen en su dibujo de la pared
        Actores = @(
            @{ Id = 'N'; Gif = 'skins\nanachi\nanachi.png'; Rect = @(612, 46, 146, 274); Respira = $true }
            # Mitty en su forma de Hueco (modelo del videojuego), a su lado; se le puede acariciar
            @{ Id = 'M'; Gif = 'skins\nanachi\mitty.png'; Rect = @(522, 196, 104, 76); Respira = $true }
        )
        Caritas = @{
            chulo = 'skins\nanachi\chulo.gif'; feliz = 'skins\nanachi\feliz.gif'; nnaa = 'skins\nanachi\nnaa.gif'; mimos = 'skins\nanachi\mimos.gif'
            verguenza = 'skins\nanachi\verguenza.gif'; tapa = 'skins\nanachi\tapa.gif'; risa = 'skins\nanachi\risa.gif'; triste = 'skins\nanachi\triste.gif'
            mastica = 'skins\nanachi\mastica.gif'; sentado = 'skins\nanachi\sentado.gif'; ronroneo = 'skins\nanachi\ronroneo.gif'
        }
        Estofado = 'skins\nanachi\estofado.png'
        Sonidos = @{
            silbato = @('skins\nanachi\silbato.wav'); viento = @('skins\nanachi\viento.wav'); burbujas = @('skins\nanachi\burbujas.wav')
            plof = @('skins\nanachi\plof.wav'); brillo = @('skins\nanachi\brillo.wav'); sorbo = @('skins\nanachi\sorbo.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 246 236 212); BurTexto = (C 60 44 34); BurFuente = 'Trebuchet MS'
        # el estofado del Abismo (receta de verdad del manga) y lo que cae en la olla con cada app
        Ingredientes = @('un pez demonio entero (machacado)', 'un huevo de picomartillo gigante', 'hierba amarilla, bien pegajosa', 'Gintoko desmigado', 'sal. Lo único normal')
        Hola = @(
            'Nnaa. Soy Nanachi. Un "Hueco", dicen. Me da igual cómo me llames. Pasa. O no.'
            '*Te mira desde el sofá de musgo.* Ah. Hola. ...¿Ya? Vale.'
            '4ª capa, 7.100 metros. Aquí no pasa nada. Me gusta que no pase nada.'
            'Nnaa... ¿qué quieres? Si es para tocarme, la respuesta es "meh".'
            '*Bosteza.* Hola. Esa de ahí es Mitty. A ella sí la saludas bien.'
        )
        AlVenirDe = @{
            'c00lgui'              = 'Se ha ido la caja roja que grita. Me ha llamado "furry.exe". Nnaa. Qué falta de respeto.'
            'SeaDrive'             = 'Se fue SeaDrive. Somos de pocas palabras. Nos hemos entendido sin hablar. Perfecto.'
            'Static Miku'          = 'La tele se ha apagado. Mucho ruido para una pantalla tan pequeña.'
            'Guillotina'           = 'La gata gigante se ha ido. Se ha comido mi olla de estofado. Entera. Y le ha gustado. Me preocupa.'
            'Angela'               = 'Se ha ido la IA de la empresa. Me ha mirado como a un "espécimen". Conozco esa mirada. No me gusta.'
            'Mikaela'              = 'La francotiradora se ha ido. Le he vendado un dedo. Se hizo daño disparando. Típico.'
            'Zodiac'               = 'El vaquero se fue. Me dijo "no te muevas". En el Abismo, si no te mueves, te comen. Nnaa.'
            'Velvet'               = 'Se ha ido la araña. Me invitó a cenar. Conozco a los que sonríen así. Dije que no.'
            'Dune'                 = 'Se fue Dune. Probó mi estofado y pidió más. Por fin alguien con buen gusto. O ninguno.'
            'Cordero y Cabra'      = 'El culto se ha ido. Me ofrecieron ser obispo. Ya tengo bastante con lo mío, gracias.'
            'Pyrophina y Zaratana' = 'Se han ido las kaijus. En la 4ª capa hay bichos peores. Ni me he despeinado.'
            'Averi'                = 'Se fue la zorrita. Me cambió medio sándwich por un cuenco de estofado. Mal negocio. Para ella.'
            'Sebastian Solace'     = 'El tendero se ha ido. Le vendí un antídoto de picadura de Orb Piercer. Me pagó en pilas. Nnaa.'
            'Pursuer'              = 'Se fue el del bosque. Dijo "carne fresca". Le contesté que yo ya no soy carne de nada. Se quedó pensando.'
            'Kasane Teto'          = 'Teto se ha ido. Me ha dejado media baguette. Le pondré estofado encima. A ver qué pasa.'
            'Token'                = 'Se fue Token. Mucho ruido. En el Abismo el ruido atrae cosas. Que lo sepas.'
            'Tetra'                = 'Tetra se ha ido. Tampoco habla mucho. Me cae bien.'
            'Kevin'                = 'Se fue Kevin. Le ofrecí estofado. Me ofreció cero pizza. Somos iguales. Más o menos.'
            'Kennyoung'            = 'Se fue el músico. Tocaba bajito por si dormía. Nnaa. Qué detalle.'
            'Enfosi'               = 'Se fue lo de la estatua. Cosas que parecen amigas y no lo son... eso lo conozco bien.'
            'Gran'                 = '*Se le eriza el pelo.* Se ha ido Gran. Bien. Que no vuelva. Los que experimentan con niños no son bienvenidos aquí.'
            'Evil Scary'           = 'Nnaa. Se ha ido la bola negra. ...menos mal. Mitty, ya puedes dejar de temblar.'
            'Soft Fuzzy Man'       = 'Se fue la nube rosa. Nnaa. Ya puedo respirar sin oler a algodón de azúcar.'
        }
        Yo = @(
            'Ese botón soy yo. Elígeme o no. Me da igual. ...Mitty se alegraría, eso sí.'
            'Si me eliges, no esperes mucha conversación.'
        )
        Opina = @{
            'c00lgui'              = @('c00lgui grita en rojo todo el rato. En el Abismo eso no duraría ni una capa.', 'Me ha intentado "hackear". No tengo nada que hackear. Soy de pelo.')
            'SeaDrive'             = @('SeaDrive está siempre cansada. Le hice una infusión de la 4ª capa. Se durmió dos días. Funciona.', 'SeaDrive y yo podríamos estar una tarde entera en silencio. Lo mejor.')
            'Static Miku'          = @('Miku sonríe mucho. A veces la gente que sonríe así lo está pasando mal por dentro. A veces no. Nnaa.', 'Su tele hace un ruido que me recuerda al campo de fuerza. Me da dolor de orejas.')
            'Guillotina'           = @('Guillotina se lo come todo. Hasta mi estofado. Respeto, pero también miedo.', 'Una gata del tamaño de una casa. En la 5ª capa las hay peores. No muchas.')
            'Angela'               = @('Angela trabaja para una empresa que encierra "anomalías" para investigarlas. Yo fui una anomalía. No me gusta esa palabra.', 'Habla con mucha calma de cosas terribles. Conozco a alguien así. Con casco.')
            'Mikaela'              = @('Mikaela tiene buena puntería. En el Abismo le iría bien. Hasta que le dé por subir.', 'Le curé una herida. Me dio las gracias con un "GG". No sé qué es, pero lo acepto.')
            'Zodiac'               = @('Zodiac dispara a lo que se mueve. En la 4ª capa se movería todo el rato. Se quedaría sin balas en un minuto.', 'Tiene algo roto por dentro. No lo digo con maldad. Se nota, nada más.')
            'Velvet'               = @('Velvet sonríe como un bicho del Abismo antes de comerte. No me fío.', 'Una araña que invita a cenar. Ya. Y yo soy un peluche.')
            'Dune'                 = @('Dune se comió mi estofado y pidió más. Es la única crítica buena que he tenido. Nnaa.', 'Dune vive en el agua. En la 4ª capa hay agua caliente. Le encantaría.')
            'Cordero y Cabra'      = @('Un cordero con una corona y una cabra que grita. En el Abismo he visto cosas más raras. Pocas.', 'Me ofrecieron unirme a su culto. Ya me han "bendecido" una vez. No quiero otra.')
            'Pyrophina y Zaratana' = @('Las kaijus pelean muy fuerte. Les curaría las heridas si dejaran de pelear cinco minutos.', 'Pyrophina podría cocinar mi estofado. Con fuego de verdad. Saldría peor. O igual.')
            'Averi'                = @('Averi dice cosas que suenan mal pero las dice con cariño. Riko también hace eso a veces.', 'Me dio un abrazo sin avisar. Nnaa. ...no pasa nada. Pero que no se repita. Mucho.')
            'Sebastian Solace'     = @('Sebastian vende botiquines. Yo los hago con setas. Somos competencia.', 'Su tienda está en un sitio oscuro y lleno de monstruos. Como mi casa. Pero con precios.')
            'Pursuer'              = @('Pursuer persigue a la gente. Yo me escondo de la gente. Nos complementamos.', 'Dice "carne fresca". Por cómo huele, no ha probado mi estofado.')
            'Kasane Teto'          = @('Teto se olvida de todo. A veces olvidar es un regalo. Otras no. Nnaa.', 'Dice que su pelo son taladros. Yo tengo orejas de conejo y no voy diciendo nada.')
            'Token'                = @('Token es una ficha que no para de sonar. En el Abismo le habrían comido el primer día.', 'Me puso su música. Me tapé las orejas. Las cuatro. Bueno, tengo dos, pero son muy grandes.')
            'Tetra'                = @('Tetra deja los mensajes en visto. Yo dejo a los exploradores en visto desde mi escondite. Igual.', 'Tetra come fideos. Le ofrecí estofado. Siguió con los fideos. Lista.')
            'Kevin'                = @('Kevin defiende su pizza como si fuera lo último que le queda. Lo entiendo más de lo que parece.', 'Le dije que mi estofado es mejor que su pizza. Me sacó una motosierra. Era mentira, de todos modos.')
            'Kennyoung'            = @('Kennyoung toca la guitarra. Una vez tocó algo tranquilo para mí. No se lo digas a nadie.', 'Tiene orejas grandes y cola. Casi parecemos familia. Casi.')
            'Enfosi'               = @('En Enfosi hay cosas que parecen buenas y no lo son. El Abismo es igual. Aprende a mirar bien.', 'Defender una estatua... yo defendí algo así una vez. Muchos años.')
            'Gran'                 = @('Gran convierte a la gente en otra cosa con jeringuillas. Yo sé lo que se siente al otro lado. No es un "éxito".', '*Se le eriza el pelo.* No quiero hablar de Gran. De verdad que no.')
            'Evil Scary'           = @('Veo el campo de fuerza. Evil Scary no sale en él. No sigue ninguna regla. Nnaa.', 'Paso de todo. De Evil Scary, no. Ese no.')
            'Soft Fuzzy Man'       = @('Soft Fuzzy Man no tiene campo de fuerza. Solo niebla. Y muchas ganas de hablar.', 'Me llamó "cosa mullida". Le tiré el cucharón. Le atravesó. Nnaa.')
        }
        Frases = @(
            'Abierto. Ya está. No me des las gracias, me da igual.'
            'Nnaa. Hecho. Vuelvo a no hacer nada.'
            'Abierto. ¿Ves? Fácil. Ahora déjame.'
            '*Lo abre sin mirar.* Listo. Mitty, no te muevas, ¿eh? ...ah, ya, si no te mueves.'
        )
        Idle = @(
            '*No se mueve del sitio.* Estoy pensando. O durmiendo. Da igual.'
            'Veo el campo de fuerza. Hilos por todas partes. Es bonito. Tampoco te creas que me emociona.'
            'La maldición: 1ª capa, mareo. 2ª, náuseas. 3ª, alucinaciones. 4ª, sangras. 5ª, pierdes la cabeza. 6ª... bah. Tú no vas a bajar tanto.'
            '*Remueve la olla con desgana.* El estofado está... ahí. Existe. Con eso basta.'
            'Huelo bien. Es una "bendición". Me la dieron sin preguntar. Típico.'
            '*Dibuja algo. Lo deja a medias.* ...luego lo acabo. O nunca.'
            'Mitty quería ser Silbato Blanco. Yo no quería ser nada. Sigo igual.'
            '*Le arregla el pelo a Mitty con mucho cuidado. Luego te mira.* ¿Qué? Con ella es distinto.'
            'Los exploradores bajan, gritan, se hacen daño y suben. Yo los miro desde aquí. Mejor que la tele.'
            'Silbato rojo, azul, luna, negro y blanco. Cuanto más alto el rango, más locos. Yo no tengo silbato. Ni ganas.'
            '*Se rasca la oreja con la pata de atrás.* No has visto nada. Y si lo has visto, me da igual.'
            'No me llames "mullido". ...bueno, llámame lo que quieras. Me da lo mismo. Pero no.'
            '*Mitty hace un ruidito.* ...sí, Mitty. Yo también me aburro. Es lo mejor del día.'
        )
        Clic = @(
            '¿Mm?'
            'Nnaa. ¿Qué?'
            '*Mueve una oreja. Solo una. La otra no tiene ganas.*'
            'Meh.'
        )
        PorApp = @{
            'YouTube'       = @('YouTube. Busca vídeos del Abismo. Hay gente que dice que es bonito. Lo es. Y te mata.')
            'Word'          = @('¿Escribir? Yo dibujo. Pero vale. Apunta lo que veas, como en un diario de exploración.')
            'Excel'         = @('Tablas. Apunta cuántos metros bajas y cuánta maldición tienes al subir. Te salvará la vida.')
            'PowerPoint'    = @('Diapositiva 1: no subas deprisa. Diapositiva 2: no subas deprisa. Fin.')
            'Outlook'       = @('Correo. En el Abismo se mandan cartas en globos. Llegan tarde. Como tus correos.')
            'OneNote'       = @('Apunta: setas buenas, setas malas. Si no sabes cuál es cuál, no te las comas.')
            'Access'        = @('Una base de datos. Mete todas las criaturas de la 4ª capa. Tardarás años. Yo tardé.')
            'Publisher'     = @('¿Un cartel? Pon mi dibujo. Saldrá mejor que en foto.')
            'Teams'         = @('Una reunión. Pon la cámara apagada. Yo también me escondo mucho.')
            'OneDrive'      = @('Tus cosas en una nube. Las mías en un escondite. Más seguro el mío.')
            'Office Web'    = @('Internet. Como el Abismo: profundo, raro, y lo que encuentras no siempre es bueno.')
            'Bloc de notas' = @('Una hoja en blanco. Perfecta para dibujar. *Te quita el ratón.* Era broma.')
            'Calculadora'   = @('7.100 metros de profundidad. Para subir 10 metros ya notas la maldición. Haz la cuenta. Mejor no.')
            'Explorador'    = @('A explorar. Como un buen Cave Raider. Pero sin subir de golpe.')
            'CMD'           = @('Pantalla negra. Como el fondo del Abismo. Nadie sabe qué hay. Yo tampoco.')
            'GitHub'        = @('GitHub. Muchas cosas raras hechas por humanos. Me recuerda a las reliquias.')
            'Wikipedia'     = @('Wikipedia. Busca "Abismo". No vas a encontrar el de verdad. Mejor así.')
        }
        # al acariciarle (cada vez más incómodo) y cuando el medidor de mullido llega al máximo
        Mimos1 = @(
            '...vale. Sigue. O para. Como quieras.'
            '*Ni se inmuta. Cierra los ojos.* Mm.'
            'Nnaa. Detrás de la oreja. Ahí. Ya está, no te emociones.'
        )
        Mimos2 = @(
            '¿Otra vez? Nnaa... qué pesado. ...no he dicho que pares.'
            '*Suspira muy largo.* Vale. Soy mullido. Ya lo sabíamos todos.'
            'Tienes mucho tiempo libre, ¿no? Yo también. Por eso no me quejo. Del todo.'
        )
        Mimos3 = @(
            'Vale, ya. *Se da la vuelta y se tumba de espaldas.* Hemos terminado.'
            '*Se aparta dos pasos. Ni uno más, que da pereza.* Basta.'
            'Nnaa. Acaricia a Mitty, que le gusta. A mí no. Bueno, un poco. Pero no.'
        )
        MullidoMax = @(
            '*Se rinde del todo. Se queda en el suelo, panza arriba.* ...nnaa. Tú ganas. Me da igual. Sigue.'
            'Mullido máximo. Enhorabuena. No hay premio. *Bosteza.*'
            '*Hace algo parecido a ronronear. Lo niega.* No ha pasado nada.'
        )
        Mitty = @(
            '*Mitty hace un ruidito suave.* ...le gusta. Sigue. A ella sí.'
            '*Nanachi se incorpora por primera vez en todo el día.* Con cuidado. Despacio. Así.'
            '*Mitty mueve una pata.* ...¿lo has visto? Le has caído bien. A mí no me pasa eso.'
            'Mitty no habla. Pero se nota cuando está contenta. Ahora lo está. Gracias. ...no se lo digas a nadie.'
        )
    }
}

# ================= GRUPOS DEL MENÚ SKINS =================
# El menú Skins enseña las skins agrupadas según de dónde viene cada personaje: una página por grupo
# (con < y > se pasa de un grupo a otro). Cada línea es:  'nombre de la skin' = 'de dónde viene'
# y eso último sale debajo del nombre, como el canal en YouTube.
# El orden de aquí es el orden del menú. Una skin que no esté en ningún grupo sale sola en "Otras".
$GruposSkins = [ordered]@{
    'YouTube' = [ordered]@{
        'SeaDrive'    = 'YonKaGor'
        'Tetra'       = 'YonKaGor'
        'Kennyoung'   = 'Kennyoung'
        'Token'       = 'femtanyl'
        'Static Miku' = 'Flavor Foley'
        'Kasane Teto' = 'Jamie Paige'
        'Kevin'       = 'Nyanwolf'
        'Gran'        = 'ivycomb'
    }
    'Roblox' = [ordered]@{
        'c00lgui'          = 'c00lkidd'
        'Mikaela'          = 'PURSUITCORE'
        'Sebastian Solace' = 'Pressure'
        'Pursuer'          = 'Die of Death'
        'Enfosi'           = 'Tumore'
    }
    'Videojuegos' = [ordered]@{
        'Guillotina'           = 'Mewgenics'
        'Zodiac'               = 'Mewgenics'
        'Pyrophina y Zaratana' = 'Mewgenics'
        'Velvet'               = 'Gunsaw'
        'Dune'                 = 'Gunsaw'
        'Angela'               = 'Lobotomy Corp.'
        'Cordero y Cabra'      = 'Cult of the Lamb'
    }
    'Halloween' = [ordered]@{
        'Evil Scary' = 'Die of Death'
        'Soft Fuzzy Man' = 'Lemon Demon · Aimkid'
    }
    'Anime' = [ordered]@{
        'Nanachi' = 'Made in Abyss'
    }
    'Artistas' = [ordered]@{
        'Averi' = 'Fiddleafox'
    }
}
$SkinsPorPagina = 9   # 3 columnas x 3 filas; un grupo con más skins ocupa varias páginas

# lista de páginas del menú Skins: cada una con su grupo y sus skins (@{ Nombre; Origen })
function Paginas-Skins {
    $grupos = [ordered]@{}; $puestas = @{}
    foreach ($gr in $GruposSkins.Keys) {
        $lista = New-Object System.Collections.ArrayList
        foreach ($n in $GruposSkins[$gr].Keys) {
            if ($Skins.Contains($n) -and -not $puestas.ContainsKey($n)) { [void]$lista.Add(@{ Nombre = $n; Origen = $GruposSkins[$gr][$n] }); $puestas[$n] = $true }
        }
        if ($lista.Count -gt 0) { $grupos[$gr] = $lista }
    }
    $resto = New-Object System.Collections.ArrayList
    foreach ($n in $Skins.Keys) { if (-not $puestas.ContainsKey($n)) { [void]$resto.Add(@{ Nombre = $n; Origen = '' }) } }
    if ($resto.Count -gt 0) { $grupos['Otras'] = $resto }
    $paginas = New-Object System.Collections.ArrayList
    foreach ($gr in $grupos.Keys) {
        $lista = $grupos[$gr]; $partes = [int][Math]::Ceiling($lista.Count / $SkinsPorPagina)
        for ($p = 0; $p -lt $partes; $p++) {
            $items = New-Object System.Collections.ArrayList
            for ($i = $p * $SkinsPorPagina; $i -lt [Math]::Min($lista.Count, ($p + 1) * $SkinsPorPagina); $i++) { [void]$items.Add($lista[$i]) }
            [void]$paginas.Add(@{ Grupo = $gr; Parte = $p + 1; Partes = $partes; Items = $items })
        }
    }
    return ,$paginas
}
# en qué página del menú está una skin (para abrir el menú justo en su grupo)
function Pagina-De-Skin($nombre) {
    $ps = Paginas-Skins
    for ($i = 0; $i -lt $ps.Count; $i++) { foreach ($it in $ps[$i].Items) { if ($it.Nombre -eq $nombre) { return $i } } }
    return 0
}

# la primera vez que se abre (sin skin.txt) sale SeaDrive: es la skin con menos luces y movimiento
$script:skinNombre = 'SeaDrive'
if (Test-Path $ArchivoSkin) { $s = (Get-Content $ArchivoSkin -Raw).Trim(); if ($Skins.Contains($s)) { $script:skinNombre = $s } }

$PorPagina = 12
$script:pagina = 0
$script:modoSkins = $false
$script:pagSkins = 0   # página del menú Skins que se está viendo
$script:glitching = $false
$script:transicion = $false
$script:pb = $null
$script:imgs = @{}
$script:caras = @{}
$script:caraModo = 'cerrados'
$script:tvRuido = $null
$script:urlLbl = $null
$script:bi = 0
$script:energia = 0
function Contar-Paginas { $script:totalPaginas = [int][Math]::Max(1, [Math]::Ceiling(@($script:Botones).Count / $PorPagina)) }
Contar-Paginas

function Azar($lista) { if ($lista -and @($lista).Count -gt 0) { $l = @($lista); return $l[$Rnd.Next($l.Count)] } else { return '' } }
function Ocupado { return ($script:glitching -or $script:transicion) }
function Ruta($rel) { return (Join-Path $Raiz $rel) }

function Doble-Buffer($ctl) {
    [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance').SetValue($ctl, $true, $null)
}

try { Add-Type -AssemblyName PresentationCore } catch {}
$script:reproductores = New-Object System.Collections.ArrayList
function Sonido($clave) { Sonido-De $script:skinNombre $clave }
$script:ultimoSonido = 0
function Sonido-De($nombre, $clave) {
    $k = $Skins[$nombre]
    if (-not $k -or -not $k.Sonidos -or -not $k.Sonidos[$clave]) { return }
    if (-not $script:aj.Sonido) { return }
    $script:ultimoSonido = [Environment]::TickCount
    try {
        $ruta = Ruta (Azar $k.Sonidos[$clave])
        if ($ruta -like '*.mp3' -or $k.Mezclar -or $script:aj.Volumen -lt 100) {
            # los mp3 (y las skins que mezclan sonidos) se reproducen con el reproductor de Windows: pueden sonar a la vez
            $mp = New-Object System.Windows.Media.MediaPlayer
            $mp.Open([Uri]$ruta); $mp.Volume = [Math]::Max(0.0, [Math]::Min(1.0, $script:aj.Volumen / 100.0)); $mp.Play()
            [void]$script:reproductores.Add($mp)
            if ($script:reproductores.Count -gt 12) { $script:reproductores[0].Close(); $script:reproductores.RemoveAt(0) }
        } else {
            $p = New-Object System.Media.SoundPlayer($ruta); $p.Play()
        }
    } catch {}
}

# hitmarker estilo shooter (X blanca con borde negro)
function Dibujar-Hit($g, $x, $y, $s) {
    $negro = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 5); $blanco = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2.5)
    foreach ($pen in @($negro, $blanco)) {
        $g.DrawLine($pen, ($x - $s), ($y - $s), ($x - $s * 0.35), ($y - $s * 0.35)); $g.DrawLine($pen, ($x + $s), ($y - $s), ($x + $s * 0.35), ($y - $s * 0.35))
        $g.DrawLine($pen, ($x - $s), ($y + $s), ($x - $s * 0.35), ($y + $s * 0.35)); $g.DrawLine($pen, ($x + $s), ($y + $s), ($x + $s * 0.35), ($y + $s * 0.35))
    }
    $negro.Dispose(); $blanco.Dispose()
}

# texto grueso con borde negro (para los carteles)
function Texto-Borde($g, $txt, $fuente, $tam, $x, $y, $color) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, $tam, (New-Object System.Drawing.PointF($x, $y)), [System.Drawing.StringFormat]::GenericDefault)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 8); $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $path); $g.FillPath((New-Object System.Drawing.SolidBrush($color)), $path)
    $pen.Dispose(); $path.Dispose()
}

# ruido de tele (estática) rápido: bytes aleatorios en una imagen en escala de grises
function Nuevo-Ruido($w, $h) {
    $b = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format8bppIndexed)
    $pal = $b.Palette
    for ($i = 0; $i -lt 256; $i++) { $pal.Entries[$i] = [System.Drawing.Color]::FromArgb($i, $i, $i) }
    $b.Palette = $pal
    Llenar-Ruido $b
    return $b
}
function Llenar-Ruido($b) {
    $r = New-Object System.Drawing.Rectangle(0, 0, $b.Width, $b.Height)
    $d = $b.LockBits($r, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $b.PixelFormat)
    $n = $d.Stride * $b.Height
    $bytes = New-Object byte[] $n
    $Rnd.NextBytes($bytes)
    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $d.Scan0, $n)
    $b.UnlockBits($d)
}

# fondos pre-dibujados (se dibujan una vez y se reutilizan)
function Fondo-Hexagonos($W, $H, $color) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $pen = New-Object System.Drawing.Pen($color, 1)
    $r = 13; $hw = [Math]::Sqrt(3) * $r; $j = 0
    for ($y = 0.0; $y -lt $H + $r; $y += 1.5 * $r) {
        $off = if ($j % 2) { $hw / 2 } else { 0 }
        for ($x = $off; $x -lt $W + $hw; $x += $hw) {
            $pts = New-Object 'System.Drawing.PointF[]' 6
            for ($q = 0; $q -lt 6; $q++) { $a = [Math]::PI / 180 * (60 * $q - 30); $pts[$q] = New-Object System.Drawing.PointF(($x + $r * [Math]::Cos($a)), ($y + $r * [Math]::Sin($a))) }
            $g.DrawPolygon($pen, $pts)
        }
        $j++
    }
    $pen.Dispose(); $g.Dispose()
    return $bmp
}
function Fondo-Papel($W, $H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $g.Clear((C 232 220 190))
    $r2 = New-Object System.Random(7)
    $b1 = New-Object System.Drawing.SolidBrush((C 214 198 162)); $b2 = New-Object System.Drawing.SolidBrush((C 222 208 175))
    for ($i = 0; $i -lt 260; $i++) { $s = $r2.Next(2, 9); $g.FillEllipse((@($b1, $b2)[$r2.Next(2)]), $r2.Next($W), $r2.Next($H), $s, $s) }
    $b1.Dispose(); $b2.Dispose(); $g.Dispose()
    return $bmp
}
function Fondo-Casa($W, $H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    # papel pintado a rayas con rombos
    for ($x = 0; $x -lt $W; $x += 24) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 62 44 52))), $x, 0, 12, $H)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 52 36 44))), ($x + 12), 0, 12, $H)
    }
    $orn = New-Object System.Drawing.SolidBrush((C 78 56 64))
    for ($y = 70; $y -lt 270; $y += 30) { for ($x = 6; $x -lt $W; $x += 24) {
        $o = if ((($y - 70) / 30) % 2) { 12 } else { 0 }
        $g.FillPolygon($orn, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(($x + $o), ($y - 5))), (New-Object System.Drawing.PointF(($x + $o + 4), $y)), (New-Object System.Drawing.PointF(($x + $o), ($y + 5))), (New-Object System.Drawing.PointF(($x + $o - 4), $y))))
    } }
    $orn.Dispose()
    # zócalo y suelo de madera
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 34 24 26))), 0, 262, $W, 6)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 92 60 40))), 0, 268, $W, ($H - 268))
    $junta = New-Object System.Drawing.Pen((C 62 40 26), 1)
    foreach ($y in @(282, 298, 314, 330)) { $g.DrawLine($junta, 0, $y, $W, $y) }
    $r2 = New-Object System.Random(3)
    foreach ($y in @(268, 282, 298, 314, 330)) { for ($x = $r2.Next(0, 80); $x -lt $W; $x += $r2.Next(70, 140)) { $g.DrawLine($junta, $x, $y, $x, ($y + 15)) } }
    $junta.Dispose(); $g.Dispose()
    return $bmp
}
function Fondo-Desierto($W, $H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    # cielo con tres tonos de atardecer
    $cielo = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 56, $W, 212)), (C 0 0 0), (C 0 0 0), 90)
    $mezcla = New-Object System.Drawing.Drawing2D.ColorBlend(3)
    $mezcla.Colors = @((C 196 78 64), (C 242 140 66), (C 252 212 146)); $mezcla.Positions = @([float]0, [float]0.5, [float]1)
    $cielo.InterpolationColors = $mezcla
    $g.FillRectangle($cielo, 0, 56, $W, 212); $cielo.Dispose()
    # sol con halo
    foreach ($q in @(@(70, 40), @(50, 60), @(36, 90))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($q[1], 255, 224, 150))), (525 - $q[0]), (196 - $q[0]), (2 * $q[0]), (2 * $q[0])) }
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 236 160))), 497, 168, 56, 56)
    # montañas lejanas y mesetas
    $lej = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 240)), (New-Object System.Drawing.PointF(60, 214)), (New-Object System.Drawing.PointF(110, 228)), (New-Object System.Drawing.PointF(190, 200)), (New-Object System.Drawing.PointF(260, 226)), (New-Object System.Drawing.PointF(340, 206)), (New-Object System.Drawing.PointF(420, 230)), (New-Object System.Drawing.PointF(500, 210)), (New-Object System.Drawing.PointF(616, 232)), (New-Object System.Drawing.PointF(616, 270)), (New-Object System.Drawing.PointF(0, 270)))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 200 112 84))), $lej)
    $mes = New-Object System.Drawing.SolidBrush((C 160 76 48))
    $g.FillPolygon($mes, [System.Drawing.Point[]]@((New-Object System.Drawing.Point(0, 268)), (New-Object System.Drawing.Point(24, 238)), (New-Object System.Drawing.Point(140, 238)), (New-Object System.Drawing.Point(168, 268))))
    $g.FillPolygon($mes, [System.Drawing.Point[]]@((New-Object System.Drawing.Point(390, 268)), (New-Object System.Drawing.Point(428, 230)), (New-Object System.Drawing.Point(548, 230)), (New-Object System.Drawing.Point(600, 268))))
    $mes.Dispose()
    # arena con granitos
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 232 192 126))), 0, 266, $W, ($H - 266))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 214 170 104))), 0, 266, $W, 3)
    $r2 = New-Object System.Random(11); $gr = New-Object System.Drawing.SolidBrush((C 206 160 96))
    for ($i = 0; $i -lt 160; $i++) { $g.FillEllipse($gr, $r2.Next($W), $r2.Next(270, $H), 2, 2) }
    $gr.Dispose()
    # saguaros
    $cac = New-Object System.Drawing.SolidBrush((C 66 108 56)); $bor = New-Object System.Drawing.Pen((C 40 70 34), 1.5)
    foreach ($cx in @(48, 318)) {
        foreach ($pz in @(@($cx, 270, 10, 34, 5), @(($cx - 10), 280, 8, 14, 4), @(($cx - 10), 290, 14, 6, 3), @(($cx + 12), 276, 8, 12, 4), @(($cx + 6), 286, 14, 6, 3))) {
            $p = Ruta-Redonda $pz[0] $pz[1] $pz[2] $pz[3] $pz[4]; $g.FillPath($cac, $p); $g.DrawPath($bor, $p); $p.Dispose()
        }
    }
    $cac.Dispose(); $bor.Dispose(); $g.Dispose()
    return $bmp
}
# dibuja una imagen cubriendo un recuadro (recorta lo que sobra); $ancla = qué parte se conserva (0..1)
function Imagen-Cubrir($g, $ruta, $x, $y, $w, $h, $ax, $ay) {
    $propia = $ruta -is [string]
    $img = if ($propia) { Cargar-Img $ruta } else { $ruta }
    if (-not $img) { return }
    $s = [Math]::Max($w / $img.Width, $h / $img.Height); $sw = $w / $s; $sh = $h / $s
    $src = New-Object System.Drawing.RectangleF([float](($img.Width - $sw) * $ax), [float](($img.Height - $sh) * $ay), [float]$sw, [float]$sh)
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)), $src, [System.Drawing.GraphicsUnit]::Pixel)
    if ($propia) { $img.Dispose() }
}
function Degradado($g, $x, $y, $w, $h, $c1, $c2, $ang) {
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)), $c1, $c2, [float]$ang)
    $g.FillRectangle($br, [float]$x, [float]$y, [float]$w, [float]$h); $br.Dispose()
}
function ARGB($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
# ---- Zodiac: atardecer del oeste dibujado (cielo, sol con franjas, mesetas, suelo y carretera) ----
function Pintar-Atardecer($g, $x, $y, $w, $h, $hor, $sx, $sr) {
    $st = $g.Save()
    $g.SetClip((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)))
    $cielo = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]($y - 1), [float]$w, [float]($hor - $y + 2))), [System.Drawing.Color]::Black, [System.Drawing.Color]::Black, [float]90)
    $cb = New-Object System.Drawing.Drawing2D.ColorBlend(4)
    $cb.Colors = [System.Drawing.Color[]]@((C 44 20 68), (C 138 38 80), (C 234 96 58), (C 255 198 100)); $cb.Positions = [float[]]@(0, 0.4, 0.78, 1)
    $cielo.InterpolationColors = $cb
    $g.FillRectangle($cielo, [float]$x, [float]$y, [float]$w, [float]($hor - $y))
    # estrellitas que se apagan con el atardecer
    $r = New-Object System.Random 7
    for ($i = 0; $i -lt 22; $i++) { $ex = $x + $r.Next(0, [int]$w); $ey = $y + $r.Next(0, [int](($hor - $y) * 0.35)); $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB (60 + $r.Next(0, 120)) 255 236 220))), [float]$ex, [float]$ey, 1.8, 1.8) }
    # rayos de sol
    $g.SetClip((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]($hor - $y))))
    $rb = New-Object System.Drawing.SolidBrush((ARGB 30 255 230 170))
    for ($i = 0; $i -lt 18; $i++) {
        $a1 = [Math]::PI / 180 * ($i * 20 - 5); $a2 = [Math]::PI / 180 * ($i * 20 + 5)
        $g.FillPolygon($rb, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$sx, [float]$hor)), (New-Object System.Drawing.PointF([float]($sx + 900 * [Math]::Cos($a1)), [float]($hor + 900 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF([float]($sx + 900 * [Math]::Cos($a2)), [float]($hor + 900 * [Math]::Sin($a2))))))
    }
    $rb.Dispose()
    # resplandor y sol con franjas
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse([float]($sx - $sr * 3), [float]($hor - $sr * 3), [float]($sr * 6), [float]($sr * 6))
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pg.CenterColor = (ARGB 160 255 226 140); $pg.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 255 160 80))
    $g.FillPath($pg, $gp); $pg.Dispose(); $gp.Dispose()
    $sol = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]($sx - $sr), [float]($hor - $sr * 1.25), [float]($sr * 2), [float]($sr * 2))), (C 255 246 176), (C 255 128 70), [float]90)
    $g.FillEllipse($sol, [float]($sx - $sr), [float]($hor - $sr * 1.25), [float]($sr * 2), [float]($sr * 2)); $sol.Dispose()
    for ($k = 0; $k -lt 4; $k++) { $by = $hor - $sr * 0.12 - $k * $sr * 0.2; $g.FillRectangle($cielo, [float]($sx - $sr - 2), [float]$by, [float]($sr * 2 + 4), [float](1.5 + (3 - $k) * 1.6)) }
    $cielo.Dispose()
    $g.SetClip((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)))
    # mesetas lejanas y cercanas
    $f = { param($fx, $fy) New-Object System.Drawing.PointF([float]($x + $w * $fx), [float]($hor - $fy)) }
    $lejos = [System.Drawing.PointF[]]@((& $f 0 0), (& $f 0 18), (& $f 0.06 18), (& $f 0.08 34), (& $f 0.22 34), (& $f 0.25 16), (& $f 0.4 16), (& $f 0.44 8), (& $f 0.62 8), (& $f 0.66 28), (& $f 0.7 40), (& $f 0.84 40), (& $f 0.87 22), (& $f 1 22), (& $f 1 0))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 168 62 86))), $lejos)
    $cerca = [System.Drawing.PointF[]]@((& $f 0 0), (& $f 0 30), (& $f 0.03 30), (& $f 0.05 52), (& $f 0.13 52), (& $f 0.16 30), (& $f 0.2 10), (& $f 0.78 6), (& $f 0.86 14), (& $f 0.9 46), (& $f 0.97 46), (& $f 0.99 24), (& $f 1 24), (& $f 1 0))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 104 34 62))), $cerca)
    # suelo del desierto
    $suelo = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]($hor - 1), [float]$w, [float]($y + $h - $hor + 2))), (C 214 110 62), (C 116 46 40), [float]90)
    $g.FillRectangle($suelo, [float]$x, [float]$hor, [float]$w, [float]($y + $h - $hor)); $suelo.Dispose()
    $g.DrawLine((New-Object System.Drawing.Pen((ARGB 150 255 214 150), 1.5)), [float]$x, [float]$hor, [float]($x + $w), [float]$hor)
    for ($i = 0; $i -lt 9; $i++) { $ey = $hor + 6 + $i * $i * 1.6; $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 34 80 20 20))), [float]($x + $r.Next(-40, [int]$w)), [float]$ey, [float](60 + $i * 14), [float](2 + $i * 0.5)) }
    # carretera que se pierde hacia el sol
    $abajo = $y + $h
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 90 70 24 30))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($sx - 4), [float]$hor)), (New-Object System.Drawing.PointF([float]($sx + 4), [float]$hor)), (New-Object System.Drawing.PointF([float]($sx + $w * 0.5), [float]$abajo)), (New-Object System.Drawing.PointF([float]($sx - $w * 0.5), [float]$abajo))))
    $raya = New-Object System.Drawing.SolidBrush((ARGB 150 255 214 120))
    foreach ($t in @(0.08, 0.2, 0.36, 0.58, 0.88)) { $t2 = $t + 0.06 + $t * 0.08; $ya = $hor + ($abajo - $hor) * $t; $yb = $hor + ($abajo - $hor) * [Math]::Min(1, $t2); $wa = 0.6 + $t * 3; $wb = 0.6 + $t2 * 3
        $g.FillPolygon($raya, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($sx - $wa), [float]$ya)), (New-Object System.Drawing.PointF([float]($sx + $wa), [float]$ya)), (New-Object System.Drawing.PointF([float]($sx + $wb), [float]$yb)), (New-Object System.Drawing.PointF([float]($sx - $wb), [float]$yb)))) }
    $raya.Dispose()
    $g.Restore($st)
}
# saguaro a contraluz (tronco y dos brazos redondeados)
function Cactus-Silueta($g, $x, $base, $alto, $col) {
    $br = New-Object System.Drawing.SolidBrush($col); $t = $alto * 0.17
    foreach ($pz in @(@(($x - $t / 2), ($base - $alto), $t, $alto), @(($x - $t * 2.1), ($base - $alto * 0.62), ($t * 0.8), ($alto * 0.34)), @(($x - $t * 2.1), ($base - $alto * 0.36), ($t * 1.8), ($t * 0.7)), @(($x + $t * 1.3), ($base - $alto * 0.8), ($t * 0.8), ($alto * 0.4)), @(($x + $t * 0.2), ($base - $alto * 0.48), ($t * 1.8), ($t * 0.7)))) {
        $p = Ruta-Redonda $pz[0] $pz[1] $pz[2] $pz[3] ($t * 0.4); $g.FillPath($br, $p); $p.Dispose()
    }
    $br.Dispose()
}
# planta rodadora: una maraña de ramitas que gira
function Dibujar-Rodadora($g, $x, $y, $rad, $ang) {
    $st = $g.Save(); $g.TranslateTransform([float]$x, [float]$y); $g.RotateTransform([float]$ang)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 70 120 70 30))), [float](-$rad), [float](-$rad), [float](2 * $rad), [float](2 * $rad))
    $r = New-Object System.Random 3
    foreach ($c in @((C 120 74 34), (C 168 116 58), (C 92 54 24))) {
        $pen = New-Object System.Drawing.Pen($c, 1.6)
        for ($i = 0; $i -lt 7; $i++) { $a = $r.Next(0, 360); $rr = $rad * (0.45 + $r.NextDouble() * 0.55); $g.DrawArc($pen, [float](-$rr + $r.Next(-3, 4)), [float](-$rr + $r.Next(-3, 4)), [float](2 * $rr), [float](2 * $rr * (0.7 + $r.NextDouble() * 0.3)), [float]$a, [float](110 + $r.Next(0, 120))) }
        $pen.Dispose()
    }
    $g.Restore($st)
}
# buitre que planea en círculos (una V que aletea despacio)
function Dibujar-Buitre($g, $x, $y, $esc, $fase) {
    $al = [Math]::Sin($fase) * 3 * $esc
    $pen = New-Object System.Drawing.Pen((ARGB 220 34 12 26), [float](2.2 * $esc)); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $g.DrawBezier($pen, [float]($x - 11 * $esc), [float]($y - 2 * $esc + $al), [float]($x - 6 * $esc), [float]($y - 6 * $esc + $al), [float]($x - 3 * $esc), [float]($y - 1 * $esc), [float]$x, [float]($y + 1 * $esc))
    $g.DrawBezier($pen, [float]($x + 11 * $esc), [float]($y - 2 * $esc + $al), [float]($x + 6 * $esc), [float]($y - 6 * $esc + $al), [float]($x + 3 * $esc), [float]($y - 1 * $esc), [float]$x, [float]($y + 1 * $esc))
    $pen.Dispose()
}
# texto con borde de color (no solo negro)
function Texto-Color($g, $txt, $fuente, $tam, $x, $y, $relleno, $borde, $grosor) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, [float]$tam, (New-Object System.Drawing.PointF([float]$x, [float]$y)), [System.Drawing.StringFormat]::GenericDefault)
    $pen = New-Object System.Drawing.Pen($borde, [float]$grosor); $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $path); $g.FillPath((New-Object System.Drawing.SolidBrush($relleno)), $path)
    $pen.Dispose(); $path.Dispose()
}
# fondo de las skins nuevas, dibujado una sola vez a la resolución real de la pantalla
function Fondo-Escena($k, $W, $H) {
    $Z = $script:K
    $bmp = New-Object System.Drawing.Bitmap([int][Math]::Ceiling($W * $Z), [int][Math]::Ceiling($H * $Z))
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
    $g.ScaleTransform($Z, $Z)
    switch ($k.Estilo) {
        'culto' {
            # el Templo del Cordero del juego
            $g.Clear((C 20 8 10))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.62
            # velo oscuro a la izquierda para los botones
            Degradado $g 0 0 420 $H (ARGB 225 18 6 9) (ARGB 150 18 6 9) 0
            Degradado $g 420 0 70 $H (ARGB 150 18 6 9) (ARGB 0 18 6 9) 0
            # sombra abajo para el pergamino y luz roja bajo los pies
            Degradado $g 400 200 ($W - 400) ($H - 200) (ARGB 0 10 2 4) (ARGB 190 10 2 4) 90
            foreach ($cx in @(504, 668)) {
                $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse([float]($cx - 70), 222, 140, 34)
                $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($p); $pg.CenterColor = (ARGB 150 220 30 40); $pg.SurroundColors = @((ARGB 0 220 30 40))
                $g.FillPath($pg, $p); $pg.Dispose(); $p.Dispose()
            }
            # barra del título
            Degradado $g 0 0 $W 56 (ARGB 240 10 4 6) (ARGB 200 10 4 6) 90
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 196 34 48))), 0, 53, [int]($W / 2), 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 130 70 190))), [int]($W / 2), 53, ($W - [int]($W / 2)), 3)
            # ojo de la corona junto al título
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 60 8 14))), ($W - 262), 14, 34, 22)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 220 30 40))), ($W - 253), 17, 16, 16)
            $g.FillEllipse([System.Drawing.Brushes]::Black, ($W - 248), 18, 6, 14)
        }
        'kaiju' {
            # el P Mart de la cinemática de las kaijus (donde se queda atrapada Tracy)
            $g.Clear((C 30 26 30))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.35 0.75
            # atardecer: tono cálido sobre la escena
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 60 120 40 20))), 0, 0, $W, $H)
            Degradado $g 0 0 420 $H (ARGB 228 14 10 16) (ARGB 160 14 10 16) 0
            Degradado $g 420 0 70 $H (ARGB 160 14 10 16) (ARGB 0 14 10 16) 0
            Degradado $g 400 210 ($W - 400) ($H - 210) (ARGB 0 8 6 10) (ARGB 200 8 6 10) 90
            # sombras de las dos en el aparcamiento
            foreach ($q in @(@(498, 70), @(666, 90))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 110 0 0 0))), [float]($q[0] - $q[1]), 236, [float](2 * $q[1]), 20) }
            # barra superior negra con franjas de peligro
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 240 12 8 10))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 200 40))), 0, 52, $W, 6)
            $neg = New-Object System.Drawing.SolidBrush((C 12 8 10))
            for ($x = -10; $x -lt $W; $x += 16) { $g.FillPolygon($neg, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF($x, 52)), (New-Object System.Drawing.PointF(($x + 8), 52)), (New-Object System.Drawing.PointF(($x + 2), 58)), (New-Object System.Drawing.PointF(($x - 6), 58)))) }
        }
        'mew' {
            # el callejón nocturno de la cinemática de Guillotina, con la farola
            $g.Clear((C 20 16 18))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.62 0.55
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 50 60 10 20))), 0, 0, $W, $H)
            Degradado $g 0 0 420 $H (ARGB 225 28 20 24) (ARGB 160 28 20 24) 0
            Degradado $g 420 0 70 $H (ARGB 160 28 20 24) (ARGB 0 28 20 24) 0
            Degradado $g 400 210 ($W - 400) ($H - 210) (ARGB 0 14 8 10) (ARGB 200 14 8 10) 90
            # sombra bajo Guillotina
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 470, 236, 250, 26)
            # barra de tinta con arañazos y borde rojo
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 28 21 24))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 170 40 35))), 0, 52, $W, 4)
            $ar = New-Object System.Drawing.Pen((C 150 60 50), 3); $ar.StartCap = 'Round'; $ar.EndCap = 'Round'
            for ($i = 0; $i -lt 3; $i++) { $g.DrawLine($ar, ($W - 228 + $i * 12), 10, ($W - 240 + $i * 12), 42) }
            $ar.Dispose()
        }
        'oeste' {
            # duelo al atardecer: cielo morado y naranja, sol enorme, mesetas y cactus a contraluz
            $g.Clear((C 40 20 14))
            Pintar-Atardecer $g 400 0 ($W - 400) $H 198 604 50
            Cactus-Silueta $g 438 206 46 (C 92 30 52)
            Cactus-Silueta $g 742 250 170 (C 34 12 24)
            # sombra de Zodiac en el suelo
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 50 14 16))), 530, 240, 140, 16)
            # pared de tablones del saloon detrás de los botones
            for ($x = 0; $x -lt 400; $x += 40) {
                $col = if (($x / 40) % 2 -eq 0) { (C 86 48 26) } else { (C 76 42 22) }
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($col)), $x, 52, 40, ($H - 52))
                $veta = New-Object System.Drawing.Pen((ARGB 60 30 14 6), 1)
                foreach ($f in @(0.25, 0.55, 0.8)) { $vx = $x + 40 * $f; $g.DrawBezier($veta, [float]$vx, 52, [float]($vx + 3), [float]($H * 0.4), [float]($vx - 3), [float]($H * 0.7), [float]$vx, [float]$H) }
                $veta.Dispose()
                $g.DrawLine((New-Object System.Drawing.Pen((C 46 24 10), 2)), $x, 52, $x, $H)
                foreach ($ny in @(62, ($H - 12))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 40 36 36))), ($x + 17), $ny, 5, 5) }
            }
            Degradado $g 0 52 400 ($H - 52) (ARGB 40 0 0 0) (ARGB 150 10 4 0) 90
            # poste de madera entre el saloon y el desierto
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 96 56 28))), 396, 52, 14, ($H - 52))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 140 90 48))), 398, 52, 3, ($H - 52))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 46 24 10))), 409, 52, 2, ($H - 52))
            # barra de madera del saloon
            $mad = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, 52)), (C 104 62 32), (C 72 40 20), 90)
            $g.FillRectangle($mad, 0, 0, $W, 52); $mad.Dispose()
            $tabla = New-Object System.Drawing.Pen((C 56 30 14), 1)
            foreach ($y in @(17, 35)) { $g.DrawLine($tabla, 0, $y, $W, $y) }
            foreach ($x in @(150, 330, 470, 640)) { $g.DrawLine($tabla, $x, 0, $x, 17); $g.DrawLine($tabla, ($x - 60), 17, ($x - 60), 35); $g.DrawLine($tabla, ($x + 40), 35, ($x + 40), 52) }
            $tabla.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 36 18 8))), 0, 52, $W, 4)
        }
        'pressure' {
            # un pasillo inundado del Hadal Blacksite (captura del juego), donde Sebastian monta su tienda
            $g.Clear((C 6 8 12))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.42
            # aclarar un poco la captura (es muy oscura)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 38 90 170 200))), 0, 0, $W, $H)
            Degradado $g 0 0 420 $H (ARGB 228 8 10 14) (ARGB 165 8 10 14) 0
            Degradado $g 420 0 70 $H (ARGB 165 8 10 14) (ARGB 0 8 10 14) 0
            # luz cálida de su farol detrás de él, y un brillo verde azulado del agua
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(450, 20, 300, 260)
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($p); $pg.CenterColor = (ARGB 70 255 200 110); $pg.SurroundColors = @((ARGB 0 255 200 110))
            $g.FillPath($pg, $p); $pg.Dispose(); $p.Dispose()
            Degradado $g 400 150 ($W - 400) ($H - 150) (ARGB 0 40 140 150) (ARGB 70 40 140 150) 90
            # cables y una lámpara colgando del techo
            $cab = New-Object System.Drawing.Pen((ARGB 200 20 24 30), 2)
            $g.DrawBezier($cab, 430, 58, 520, 80, 640, 70, 760, 62); $g.DrawLine($cab, 712, 58, 712, 92)
            $cab.Dispose()
            $g.FillPie((New-Object System.Drawing.SolidBrush((C 40 46 54))), 698, 86, 28, 22, 180, 180)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 214 140))), 706, 94, 12, 8)
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(672, 70, 80, 70)
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($p); $pg.CenterColor = (ARGB 120 255 210 140); $pg.SurroundColors = @((ARGB 0 255 210 140))
            $g.FillPath($pg, $p); $pg.Dispose(); $p.Dispose()
            # barra metálica con franja de peligro
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 8 10 14))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 190 200))), 0, 52, $W, 2)
            $am = New-Object System.Drawing.SolidBrush((C 255 190 70)); $ng = New-Object System.Drawing.SolidBrush((C 8 10 14))
            $g.FillRectangle($am, 0, 54, $W, 4)
            for ($x = -10; $x -lt $W; $x += 14) { $g.FillPolygon($ng, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF($x, 54)), (New-Object System.Drawing.PointF(($x + 6), 54)), (New-Object System.Drawing.PointF(($x + 2), 58)), (New-Object System.Drawing.PointF(($x - 4), 58)))) }
        }
        'dod' {
            # el bosque del mapa Treehouse de Die of Death, de noche
            $g.Clear((C 6 12 8))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.55 0.6
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 4 14 18))), 0, 0, $W, $H)
            Degradado $g 0 150 $W ($H - 150) (ARGB 0 160 200 180) (ARGB 60 160 200 180) 90
            Degradado $g 0 0 420 $H (ARGB 230 4 10 6) (ARGB 165 4 10 6) 0
            Degradado $g 420 0 70 $H (ARGB 165 4 10 6) (ARGB 0 4 10 6) 0
            Degradado $g 400 210 ($W - 400) ($H - 210) (ARGB 0 2 6 4) (ARGB 200 2 6 4) 90
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 535, 252, 140, 16)
            # barra negra con el logo del juego
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 245 4 8 6))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 130 91))), 0, 52, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 52 41))), 0, 55, $W, 1)
            $logo = Cargar-Img $k.TituloImg; if ($logo) { $g.DrawImage($logo, 8, 3, 141, 47); $logo.Dispose() }
        }
        'femta' {
            # la ciudad roja de la portada de "ALL THE TIME" (femtanyl), con puntos de imprenta
            $g.Clear((C 12 6 8))
            Imagen-Cubrir $g $k.FondoImg 0 52 $W ($H - 52) 0.5 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 110 40 0 8))), 0, 52, $W, ($H - 52))
            $pt = New-Object System.Drawing.SolidBrush((ARGB 46 0 0 0))
            for ($y = 56; $y -lt $H; $y += 6) { for ($x = (($y / 6) % 2) * 3; $x -lt $W; $x += 6) { $g.FillEllipse($pt, [float]$x, [float]$y, 2.4, 2.4) } }
            $pt.Dispose()
            # panel negro detrás de los botones, con borde blanco como una pegatina
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 10 6 8))), $pan); $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)), $pan); $pan.Dispose()
            # un vinilo asomando detrás de la portada
            $vx = 668; $vy = 160; $vr = 94
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 14 12 14))), ($vx - $vr), ($vy - $vr), (2 * $vr), (2 * $vr))
            $sur = New-Object System.Drawing.Pen((ARGB 50 255 255 255), 0.8)
            for ($rr = 32; $rr -lt $vr - 4; $rr += 6) { $g.DrawEllipse($sur, ($vx - $rr), ($vy - $rr), (2 * $rr), (2 * $rr)) }
            $sur.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 230 20 40))), ($vx - 26), ($vy - 26), 52, 52)
            $g.FillEllipse([System.Drawing.Brushes]::White, ($vx - 3), ($vy - 3), 6, 6)
            # barra de arriba negra con línea roja y el logo en llamas (portada de MAN BITES DOG)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 0 0))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), 0, 49, $W, 3)
            $lg = Cargar-Img $k.Logo; if ($lg) { $g.DrawImage($lg, 300, 2, 78, 46); $lg.Dispose() }
        }
        'punk' {
            # atardecer en el skatepark, como sus dibujos (fondo difuminado)
            $g.Clear((C 250 190 150))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            # panel crema detrás de los botones, con el borde verde en zigzag de sus pegatinas
            Dibujar-Pegatina $g 12 66 386 ($H - 76) (ARGB 215 255 246 236)
            # barra de arriba: los cuadros marrones de su camisa y una línea verde
            Dibujar-Cuadros $g 0 0 $W 50
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 110 235 140))), 0, 50, $W, 4)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 46 34 30))), 0, 54, $W, 2)
            # púa de guitarra verde como logo
            $pua = New-Object System.Drawing.Drawing2D.GraphicsPath
            $pua.AddBezier(12, 16, 22, 10, 32, 10, 38, 16); $pua.AddBezier(38, 16, 38, 26, 30, 34, 25, 40); $pua.AddBezier(25, 40, 20, 34, 12, 26, 12, 16)
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 235 140))), $pua); $g.DrawPath((New-Object System.Drawing.Pen((C 46 34 30), 2)), $pua); $pua.Dispose()
            # pegatina "PUNK RULZZZ"
            $st = $g.Save(); $g.TranslateTransform(440, 26); $g.RotateTransform(-5)
            $pg = Ruta-Redonda (-64) (-13) 128 26 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 235 140))), $pg); $g.DrawPath((New-Object System.Drawing.Pen((C 46 34 30), 2.5)), $pg); $pg.Dispose()
            $tw = Ancho-Texto 'PUNK RULZZZ' 'Arial Black' 13
            Texto-Contorno $g 'PUNK RULZZZ' 'Arial Black' 13 (-$tw / 2) (-10) (C 255 255 255) 3
            $g.Restore($st)
        }
        'pizza' {
            # mantel de pizzería a cuadros y, a la derecha, el Paint donde vive Kevin
            $g.Clear((C 255 255 255))
            $roja = New-Object System.Drawing.SolidBrush((ARGB 110 220 40 40))
            for ($x = 0; $x -lt $W; $x += 40) { $g.FillRectangle($roja, $x, 52, 20, ($H - 52)) }
            for ($y = 52; $y -lt $H; $y += 40) { $g.FillRectangle($roja, 0, $y, $W, 20) }
            $roja.Dispose()
            # migas y trocitos de pizza por el mantel
            $rn = New-Object System.Random 21
            for ($i = 0; $i -lt 5; $i++) { Dibujar-Trozo $g $rn.Next(20, 390) $rn.Next(70, 300) 16 $rn.Next(0, 360) }
            # panel blanco detrás de los botones, con borde de rotulador
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 16
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 255 255 255))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 20 20 20), 2.5)), $pan); $pan.Dispose()
            # la ventana de Paint: barra azul, menú, paleta de colores y lienzo blanco
            $px = 410; $py = 58; $pw = $W - 418; $ph = 214
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), ($px + 5), ($py + 5), $pw, $ph)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 212 208 200))), $px, $py, $pw, $ph)
            Degradado $g $px $py $pw 18 (C 10 36 106) (C 166 202 240) 0
            $g.DrawString('kevin.png - Paint', (FntP('Tahoma', 8, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, ($px + 20), ($py + 2))
            Dibujar-Trozo $g ($px + 10) ($py + 9) 12 180
            foreach ($bi in 0..2) {
                $bx = $px + $pw - 50 + $bi * 16
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 212 208 200))), $bx, ($py + 3), 14, 12)
                $g.DrawRectangle((New-Object System.Drawing.Pen((C 64 64 64), 1)), $bx, ($py + 3), 14, 12)
                $g.DrawString(@('_', '□', 'x')[$bi], (FntP('Tahoma', 7, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, ($bx + 2), ($py + 1))
            }
            $g.DrawString('Archivo   Edición   Ver   Imagen   Colores   Ayuda', (FntP('Tahoma', 7)), [System.Drawing.Brushes]::Black, ($px + 4), ($py + 19))
            $g.FillRectangle([System.Drawing.Brushes]::White, 414, 90, 334, 172)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 128 128 128), 1)), 413, 89, 335, 173)
            # paleta de colores de Paint abajo, con los colores de Kevin primero
            $pal = @((C 0 0 0), (C 70 200 40), (C 30 100 240), (C 255 110 200), (C 255 206 84), (C 206 40 40), (C 128 128 128), (C 255 255 255), (C 128 0 0), (C 128 128 0), (C 0 128 0), (C 0 128 128), (C 0 0 128), (C 128 0 128))
            for ($i = 0; $i -lt $pal.Count; $i++) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($pal[$i])), (416 + $i * 14), 264, 12, 6)
                $g.DrawRectangle((New-Object System.Drawing.Pen((C 90 90 90), 1)), (416 + $i * 14), 264, 12, 6)
            }
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 20 20 20), 2)), $px, $py, $pw, $ph)
            # barra de arriba verde Kevin con franjas rosa y azul
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 200 40))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 110 200))), 0, 46, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 30 100 240))), 0, 49, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 20 20 20))), 0, 52, $W, 2)
            Dibujar-Trozo $g 505 27 26 200
        }
        'pop' {
            # el acuario del videoclip "You're Just Like Pop Music", con estética de cinta VHS
            $g.Clear((C 30 14 52))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 60 40 10 80))), 0, 0, $W, $H)
            # panel oscuro con borde de neón detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 14
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 175 24 10 46))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 70 255 92 190), 6)), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 230 90 230 250), 2)), $pan); $pan.Dispose()
            # barra de arriba en degradado morado y rosa, con líneas de neón
            Degradado $g 0 0 $W 52 (C 40 12 70) (C 130 34 116) 0
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 90 230 250))), 0, 49, $W, 2)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 92 190))), 0, 51, $W, 2)
            # el logo "Failure" de su gorra
            $lg = Cargar-Img $k.Logo; if ($lg) { $g.DrawImage($lg, 420, 200, 70, 54); $lg.Dispose() }
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 20 0 40))), 578, 266, 122, 12)
        }
        'gran' {
            # el remolino de pintura de su intro, oscurecido, con el laboratorio de Antihuman Inc. encima
            $g.Clear((C 8 10 9))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 4 8 6))), 0, 0, $W, $H)
            # panel oscuro con borde verde detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 8 12 10))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 32 208 44), 2)), $pan); $pan.Dispose()
            # monitor del laboratorio donde sale Gran
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 414, 66, 340, 208)
            $g.FillRectangle([System.Drawing.Brushes]::Black, 408, 56, 346, 216)
            # barra de arriba negra con franjas rosas (como el fondo de su cara tapada) y la línea verde
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, 52)
            $rosa = New-Object System.Drawing.SolidBrush((ARGB 70 255 70 170))
            for ($x = -60; $x -lt $W; $x += 36) { $g.FillPolygon($rosa, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, 52)), (New-Object System.Drawing.PointF([float]($x + 14), 52)), (New-Object System.Drawing.PointF([float]($x + 66), 0)), (New-Object System.Drawing.PointF([float]($x + 52), 0)))) }
            $rosa.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 32 208 44))), 0, 49, $W, 3)
            # logo: una G verde en un hexágono, el color de Gran en el consejo de Golden City
            $hx = 330; $hy = 26; $hr = 19
            $pts = [System.Drawing.PointF[]]@(0..5 | ForEach-Object { $an = [Math]::PI / 3 * $_ + [Math]::PI / 6; New-Object System.Drawing.PointF([float]($hx + $hr * [Math]::Cos($an)), [float]($hy + $hr * [Math]::Sin($an))) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 10 14 11))), $pts)
            $g.DrawPolygon((New-Object System.Drawing.Pen((C 32 208 44), 2.5)), $pts)
            $tw = Ancho-Texto 'G' 'Arial Black' 18
            Texto-Contorno $g 'G' 'Arial Black' 18 ($hx - $tw / 2 - 1) ($hy - 13) (C 32 208 44) 3
        }
        'evil' {
            # la baseplate de noche con niebla roja (el mapa de la ronda especial)
            $g.Clear((C 10 4 6))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.5
            # panel oscuro con borde rojo detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 8 4 6))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 170 20 30), 2)), $pan); $pan.Dispose()
            # barra de arriba negra con el título "Evil Scary" del juego y la línea roja
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 170 20 30))), 0, 52, $W, 3)
            $ti = Cargar-Img $k.TituloImg; if ($ti) { $g.DrawImage($ti, 10, 4, 104, 46); $ti.Dispose() }
        }
        'niebla' {
            # la colina de noche con la casita del vídeo, la luna y los pinos
            $g.Clear((C 40 16 70))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.55
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 45 70 0 110))), 0, 0, $W, $H)
            # panel morado translúcido con borde rosa detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 12
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 175 46 18 80))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 90 230), 2)), $pan); $pan.Dispose()
            # barra de arriba morada con nubecitas rosas
            Degradado $g 0 0 $W 52 (C 74 28 124) (C 40 14 72) 90
            $nube = New-Object System.Drawing.SolidBrush((ARGB 60 255 180 240))
            foreach ($nx in @(330, 470, 610, 700)) { $g.FillEllipse($nube, $nx, 14, 40, 20); $g.FillEllipse($nube, ($nx + 18), 6, 36, 26); $g.FillEllipse($nube, ($nx + 40), 16, 34, 18) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 90 230))), 0, 50, $W, 3)
        }
        'abismo' {
            # su escondite de la 4ª capa (del anime), oscurecido a la izquierda para los botones
            $g.Clear((C 20 36 24))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.6 0.5
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 40 10 30 14))), 0, 0, $W, $H)
            # panel de pergamino detrás de los botones
            $pan = Ruta-Redonda 8 62 394 ($H - 68) 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 20 34 22))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((C 150 120 90), 2)), $pan); $pan.Dispose()
            # barra de arriba: cuero marrón con una cuerda de silbatos de explorador
            Degradado $g 0 0 $W 52 (C 92 66 46) (C 64 44 30) 90
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 236 170 190))), 0, 50, $W, 3)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 28 20))), 0, 53, $W, 2)
            $cu = New-Object System.Drawing.Pen((C 200 170 120), 1.5)
            $g.DrawBezier($cu, 330, 10, 380, 22, 470, 22, 520, 10); $cu.Dispose()
            $cols = @((C 210 50 50), (C 70 120 210), (C 200 200 220), (C 30 30 34), (C 250 250 250))
            for ($i = 0; $i -lt 5; $i++) { Dibujar-Silbato $g (346 + $i * 34) (18 + [Math]::Sin(($i + 0.5) / 5.0 * [Math]::PI) * 4) $cols[$i] }
        }
        'enfosi' {
            # un mapa del juego (Blibble's Field) de fondo, con la interfaz de Roblox
            $g.Clear((C 120 170 230))
            Imagen-Cubrir $g $k.FondoImg 0 0 $W $H 0.5 0.62
            # panel oscuro translúcido detrás de los botones
            $pan = Ruta-Redonda 8 60 394 ($H - 66) 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 15 18 30))), $pan)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 200 255 255 255), 2)), $pan); $pan.Dispose()
            # barra de arriba amarilla, como el Giggler, y el logo de los Glaggles
            Degradado $g 0 0 $W 52 (C 255 222 80) (C 250 176 30) 90
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 30 10))), 0, 49, $W, 3)
            $lg = Cargar-Img $k.Logo; if ($lg) { $g.DrawImage($lg, 262, 8, 118, [float]($lg.Height * 118 / $lg.Width)); $lg.Dispose() }
            # sombra de la estatua en el suelo
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), 412, 258, 112, 14)
        }
        'teto' {
            # el rosa del videoclip de BIRDBRAIN, con fotos del vídeo pegadas como en un álbum
            Degradado $g 0 0 $W $H (C 252 226 230) (C 247 208 214) 90
            $ray = New-Object System.Drawing.Pen((ARGB 70 255 255 255), 12)
            for ($x = -$H; $x -lt $W; $x += 40) { $g.DrawLine($ray, $x, 56, ($x + $H), ($H + 56)) }
            $ray.Dispose()
            # barra roja de arriba con franjas amarillas, como sus medias
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 214 40 64))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 176 24 48))), 0, 48, $W, 4)
            for ($x = 0; $x -lt $W; $x += 24) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 246 204 60))), $x, 52, 12, 6)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 252 232 150))), ($x + 12), 52, 12, 6)
            }
            # panel suave detrás de los botones
            $pan = Ruta-Redonda 8 62 392 ($H - 70) 22
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 255 255 255))), $pan); $g.DrawPath((New-Object System.Drawing.Pen((ARGB 140 214 40 64), 2)), $pan); $pan.Dispose()
            # polaroids del videoclip
            $fotos = @($k.Fotos | ForEach-Object { Cargar-Img $_ })
            Dibujar-Polaroid $g $fotos[0] 432 74 96 (-7)
            Dibujar-Polaroid $g $fotos[1] 470 176 84 6
            foreach ($f in $fotos) { if ($f) { $f.Dispose() } }
            # sombra en el suelo bajo Teto
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 55 150 20 40))), 584, 284, 120, 14)
        }
        'zorro' {
            # la casita de Averi: papel pintado a rayas, zócalo de madera y su foto en una polaroid
            Degradado $g 0 0 $W $H (C 255 246 232) (C 252 232 206) 90
            for ($x = 0; $x -lt $W; $x += 28) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 245 210 170))), $x, 56, 12, 190) }
            $pu = New-Object System.Drawing.SolidBrush((ARGB 120 236 150 90))
            for ($y = 70; $y -lt 236; $y += 28) { for ($x = 20; $x -lt $W; $x += 28) { $g.FillEllipse($pu, $x, $y, 5, 5) } }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 196 128 80))), 0, 238, $W, ($H - 238))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 168 104 62))), 0, 238, $W, 5)
            $lin = New-Object System.Drawing.Pen((C 176 112 70), 1.5)
            for ($x = 30; $x -lt $W; $x += 60) { $g.DrawLine($lin, $x, 246, $x, $H) }
            # panel suave detrás de los botones
            $pan = Ruta-Redonda 8 60 392 246 22
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 255 255 255))), $pan); $g.DrawPath((New-Object System.Drawing.Pen((ARGB 120 230 128 56), 2)), $pan); $pan.Dispose()
            # polaroid con sombra y celo
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 90 40 10))), 441, 67, 216, 188)
            $g.FillRectangle([System.Drawing.Brushes]::White, 436, 62, 216, 188)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 226 210 190), 1)), 436, 62, 216, 188)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 226 190))), 446, 72, 196, 147)
            foreach ($tx in @(430, 620)) {
                $st = $g.Save(); $g.TranslateTransform([float]($tx + 20), 64); $g.RotateTransform($(if ($tx -lt 500) { -32 } else { 32 }))
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 255 236 150))), -22, -7, 44, 14); $g.Restore($st)
            }
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString('Averi ♥', (FntP('Segoe Print', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 150 80 40))), (New-Object System.Drawing.RectangleF(436, 220, 216, 28)), $fmt)
            # barra naranja con lunares
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 128 56))), 0, 0, $W, 52)
            $lu = New-Object System.Drawing.SolidBrush((C 240 148 80))
            for ($x = 8; $x -lt $W; $x += 26) { $g.FillEllipse($lu, $x, 8, 6, 6); $g.FillEllipse($lu, ($x + 13), 32, 6, 6) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 196 100 40))), 0, 52, $W, 4)
        }
    }
    $g.Dispose()
    return $bmp
}
# bocadillos con forma propia (detrás del texto)
function Pintar-Burbuja($g, $k) {
    $b = $k.Burbuja; $x = $b[0] - 6; $y = $b[1] - 4; $w = $b[2] + 12; $h = $b[3] + 8
    switch ($k.Estilo) {
        'culto' {
            # pergamino con los extremos enrollados
            $r = Ruta-Redonda $x $y $w $h 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 236 222 192))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 120 70 40), 2)), $r); $r.Dispose()
            foreach ($ex in @(($x - 6), ($x + $w - 6))) {
                $rr = Ruta-Redonda $ex ($y - 3) 12 ($h + 6) 10
                $g.FillPath((New-Object System.Drawing.SolidBrush((C 214 196 160))), $rr); $g.DrawPath((New-Object System.Drawing.Pen((C 120 70 40), 2)), $rr); $rr.Dispose()
            }
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 170 24 34))), ($x + $w - 26), ($y + $h - 16), 16, 16)
            $g.DrawEllipse((New-Object System.Drawing.Pen((C 110 10 20), 1.5)), ($x + $w - 26), ($y + $h - 16), 16, 16)
        }
        'kaiju' {
            # caja de radio: WMEW 99.9 en directo
            $r = Ruta-Redonda $x $y $w $h 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 230 14 10 14))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 200 40), 2)), $r); $r.Dispose()
            $t = Ruta-Redonda ($x + 10) ($y - 13) 98 18 8
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 200 40))), $t); $t.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 220 30 30))), ($x + 16), ($y - 9), 9, 9)
            $g.DrawString('WMEW 99.9', (FntP('EdmundMcMillen_INTLv4', 8)), [System.Drawing.Brushes]::Black, ($x + 28), ($y - 13))
        }
        'mew' {
            # nota de papel con borde de tinta irregular, como la interfaz de Mewgenics
            $r2 = New-Object System.Random(5)
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 2), [float]($y + 1))), (New-Object System.Drawing.PointF([float]($x + $w * 0.5), [float]($y - 2))), (New-Object System.Drawing.PointF([float]($x + $w - 1), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w + 1), [float]($y + $h - 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.4), [float]($y + $h + 1))), (New-Object System.Drawing.PointF([float]($x - 1), [float]($y + $h - 1))))
            $somb = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 4), ($_.Y + 4)) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 14 8 10))), $somb)
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 246 236 210))), $pts)
            $tinta = New-Object System.Drawing.Pen((C 20 14 16), 3); $tinta.LineJoin = 'Round'
            $g.DrawPolygon($tinta, $pts); $tinta.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 160 200 60 50))), [float]($x + $w - 40), [float]($y - 8), 30, 12)
        }
        'oeste' {
            # cartel de "se busca" clavado con dos clavos
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 30 14 4))), [float]($x + 4), [float]($y + 4), [float]$w, [float]$h)
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)), (C 246 232 196), (C 226 200 150), 90)
            $g.FillRectangle($br, [float]$x, [float]$y, [float]$w, [float]$h); $br.Dispose()
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 150 105 55), 3)), [float]$x, [float]$y, [float]$w, [float]$h)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 120 80 40), 1)), [float]($x + 4), [float]($y + 4), [float]($w - 8), [float]($h - 8))
            foreach ($nx in @(($x + 10), ($x + $w - 14))) {
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 60 58 62))), [float]$nx, [float]($y + 3), 6, 6)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 170 170 175))), [float]($nx + 1.5), [float]($y + 4), 2, 2)
            }
        }
        'pressure' {
            # subtítulos del juego: caja oscura con el nombre de quien habla
            $r = Ruta-Redonda $x $y $w $h 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 4 6 8))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 70 190 200), 1.5)), $r); $r.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 190 200))), [float]$x, [float]($y + 6), 3, [float]($h - 12))
            $t2 = Ruta-Redonda ($x + 10) ($y - 12) 86 16 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 70 190 200))), $t2); $t2.Dispose()
            $g.DrawString('SEBASTIAN', (FntP('Bahnschrift', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 6 10 14))), ($x + 16), ($y - 12))
        }
        'dod' {
            # bocadillo de texto de Die of Death: negro con borde verde
            $r = Ruta-Redonda $x $y $w $h 14
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 230 2 6 4))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 0 160 110), 2.5)), $r); $r.Dispose()
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 0 160 110))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.62), [float]($y + 1))), (New-Object System.Drawing.PointF([float]($x + $w * 0.68), [float]($y - 12))), (New-Object System.Drawing.PointF([float]($x + $w * 0.72), [float]($y + 1)))))
        }
        'femta' {
            # pegatina blanca con contorno negro y sombra roja, como las portadas de femtanyl
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float]($x + 4), [float]($y + 4), [float]$w, [float]$h)
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]$x, [float]$y, [float]$w, [float]$h)
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)), [float]$x, [float]$y, [float]$w, [float]$h)
        }
        'punk' {
            # bocadillo crema con borde marrón y sombra verde, como una pegatina
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 235 140))), (Ruta-Redonda ($x + 3) ($y + 3) $w $h 12))
            $r = Ruta-Redonda $x $y $w $h 12
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 248 240))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 2)), $r); $r.Dispose()
        }
        'pizza' {
            # bocadillo de cómic dibujado con rotulador, con piquito hacia Kevin
            $r = Ruta-Redonda $x $y $w $h 14
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 120 255 110 200))), (Ruta-Redonda ($x + 4) ($y + 4) $w $h 14))
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $pk = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.70), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.80), [float]($y - 13))), (New-Object System.Drawing.PointF([float]($x + $w * 0.80), [float]($y + 2))))
            $g.FillPolygon([System.Drawing.Brushes]::White, $pk)
            $tinta = New-Object System.Drawing.Pen((C 20 20 20), 2.5); $tinta.LineJoin = 'Round'
            $g.DrawPath($tinta, $r); $r.Dispose(); $g.DrawLines($tinta, $pk); $tinta.Dispose()
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]($x + $w * 0.705), [float]($y - 1), [float]($w * 0.09), 4)
            Dibujar-Trozo $g ($x + $w - 12) ($y + $h - 10) 12 200
        }
        'pop' {
            # bocadillo morado translúcido con borde de neón rosa y cian
            $r = Ruta-Redonda $x $y $w $h 12
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 34 14 64))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 90 255 92 190), 5)), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 90 230 250), 1.6)), $r); $r.Dispose()
        }
        'gran' {
            # pantalla oscura de laboratorio con borde verde
            $r = Ruta-Redonda $x $y $w $h 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 230 8 12 10))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 80 32 208 44), 5)), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 32 208 44), 1.6)), $r); $r.Dispose()
        }
        'evil' {
            # el cartel de mensaje de Die of Death: caja oscura con borde rojo
            $r = Ruta-Redonda $x $y $w $h 4
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 22 10 12))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 170 20 30), 2)), $r); $r.Dispose()
        }
        'niebla' {
            # bocadillo morado con borde rosa neón que brilla un poco
            $r = Ruta-Redonda $x $y $w $h ([Math]::Min(14, $h / 2))
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 60 24 100))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 70 255 90 230), 5)), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 90 230), 1.6)), $r); $r.Dispose()
        }
        'abismo' {
            # nota de papel de explorador, con una esquina doblada
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 110 0 0 0))), (Ruta-Redonda ($x + 3) ($y + 3) $w $h 6))
            $r = Ruta-Redonda $x $y $w $h 6
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 246 236 212))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 120 92 66), 1.6)), $r); $r.Dispose()
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 220 200 168))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w - 12), [float]$y)), (New-Object System.Drawing.PointF([float]($x + $w), [float]($y + 12))), (New-Object System.Drawing.PointF([float]($x + $w - 12), [float]($y + 12)))))
        }
        'enfosi' {
            # bocadillo blanco del chat de Roblox, con piquito hacia la estatua
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 60 0 0 0))), (Ruta-Redonda ($x + 2) ($y + 3) $w $h 12))
            $r = Ruta-Redonda $x $y $w $h 12
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 190 190 200), 1.5)), $r); $r.Dispose()
            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 20), [float]($y + 1))), (New-Object System.Drawing.PointF([float]($x + 26), [float]($y - 10))), (New-Object System.Drawing.PointF([float]($x + 40), [float]($y + 1)))))
        }
        'teto' {
            # bocadillo blanco con borde rojo y piquito hacia Teto
            $r = Ruta-Redonda $x $y $w $h 16
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 70 176 24 48))), (Ruta-Redonda ($x + 3) ($y + 4) $w $h 16))
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $pk = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.66), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.74), [float]($y - 11))), (New-Object System.Drawing.PointF([float]($x + $w * 0.78), [float]($y + 2))))
            $g.FillPolygon([System.Drawing.Brushes]::White, $pk)
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 40 64), 2.5)), $r); $r.Dispose()
            $g.DrawLines((New-Object System.Drawing.Pen((C 214 40 64), 2.5)), $pk)
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]($x + $w * 0.665), [float]($y - 1), [float]($w * 0.11), 4)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 246 204 60))), [float]($x + $w - 16), [float]($y + 5), 8, 8)
        }
        'zorro' {
            # nube de diálogo con piquito hacia la foto
            $r = Ruta-Redonda $x $y $w $h 22
            $g.FillPath([System.Drawing.Brushes]::White, $r)
            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.55), [float]($y + 2))), (New-Object System.Drawing.PointF([float]($x + $w * 0.62), [float]($y - 12))), (New-Object System.Drawing.PointF([float]($x + $w * 0.68), [float]($y + 2)))))
            $g.DrawPath((New-Object System.Drawing.Pen((C 230 128 56), 2.5)), $r); $r.Dispose()
            $g.DrawLines((New-Object System.Drawing.Pen((C 230 128 56), 2.5)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + $w * 0.55), [float]$y)), (New-Object System.Drawing.PointF([float]($x + $w * 0.62), [float]($y - 12))), (New-Object System.Drawing.PointF([float]($x + $w * 0.68), [float]$y))))
            $g.FillRectangle([System.Drawing.Brushes]::White, [float]($x + $w * 0.56), [float]($y - 1), [float]($w * 0.11), 4)
        }
    }
}
# texto con colores: {r} rojo, {g} verde, {b} blanco
function Texto-Marcado($g, $txt, $f, $x, $y) {
    $cols = @{ r = (C 230 40 50); g = (C 40 220 60); b = (C 226 222 230) }
    $col = $cols.b; $px = [float]$x
    $sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    foreach ($trozo in ([regex]::Split($txt, '(\{[rgb]\})'))) {
        if ($trozo -match '^\{([rgb])\}$') { $col = $cols[$Matches[1]]; continue }
        if (-not $trozo) { continue }
        $g.DrawString($trozo, $f, (New-Object System.Drawing.SolidBrush($col)), $px, [float]$y, $sf)
        $px += $g.MeasureString($trozo, $f, (New-Object System.Drawing.PointF(0, 0)), $sf).Width
    }
}
$script:bmpHex = $null; $script:bmpHexIntro = $null; $script:bmpPapel = $null; $script:bmpCasa = $null; $script:bmpDesierto = $null

# ================= DIÁLOGOS (máquina de escribir + boca de Angela) =================
$script:twTexto = ''; $script:twPos = 0; $script:twTick = 0; $script:twInicio = 0
# mensajes importantes: mientras se escriben (y un rato para leerlos) nadie los pisa
$script:twBloqueo = 0; $script:twForzar = $false
$twTimer = New-Object System.Windows.Forms.Timer
$twTimer.Interval = 30
$twTimer.Add_Tick({
    if (-not $script:status -or (Ocupado)) { return }
    $script:twTick++
    $escribiendo = $script:twPos -lt $script:twTexto.Length
    if ($escribiendo) {
        $objetivo = [int](([Environment]::TickCount - $script:twInicio) / 30.0 * $script:skin.Velocidad)
        $script:twPos = [Math]::Min($script:twTexto.Length, [Math]::Max($script:twPos + $script:skin.Velocidad, $objetivo))
    }
    $txt = $script:twTexto.Substring(0, $script:twPos)
    if ($script:skin.Estilo -eq 'hacker' -and ($escribiendo -or ([Math]::Floor($script:twTick / 15) % 2 -eq 0))) { $txt += '_' }
    if ($script:status.Text -ne $txt) { $script:status.Text = $txt; Ajustar-Texto }
    Leer-Texto $escribiendo
    # personajes dibujados que hablan cambiando de boca (campo Habla de la skin: actor y bocas en orden)
    $hb = $script:skin.Habla
    if ($hb) {
        $a = $script:actores[$hb.Id]
        if ($a -and $a.Hasta -eq 0) {
            $pose = if ($escribiendo) { $hb.Bocas[[int][Math]::Floor($script:twTick / 3) % $hb.Bocas.Count] } else { 'main' }
            if ($a.Pose -ne $pose -and $a.Imgs[$pose]) { $a.Pose = $pose; $a.Frame = 0; Seleccionar-Frame $a; Invalidar-Escena }
        }
    }
    # Angela mueve la boca mientras escribe
    if ($script:pb -and $script:caras.Count -gt 0 -and -not $script:dInvitadoHabla) {
        $set = $script:caras[$script:caraModo]
        $img = if ($escribiendo -and ([Math]::Floor($script:twTick / 3) % 2 -eq 1)) { $set[1] } else { $set[0] }
        if ($script:pb.Image -ne $img) { $script:pb.Image = $img }
    }
})

function Decir($texto, $cara) {
    # si hay un mensaje importante a medias, las frases normales esperan su turno
    if ([Environment]::TickCount -lt $script:twBloqueo -and -not $script:twForzar) { return }
    $script:twTexto = [string]$texto; $script:twPos = 0; $script:twInicio = [Environment]::TickCount
    $script:textoManual = $false; $script:leerT = 0
    $k = $script:skin
    # la Cabra y el Cordero ponen voz a lo que dicen (si no acaba de sonar otra cosa)
    if ($k.Estilo -eq 'culto' -and ([Environment]::TickCount - $script:ultimoSonido) -gt 700) { Voz-Culto $texto }
    # Teto dice con su voz una palabra de lo que pone en el bocadillo
    if ($k.Estilo -eq 'teto') { Voz-Teto $texto }
    # Averi cambia de cara según cómo se siente
    if ($k.Estilo -eq 'zorro') {
        $pose = switch ($cara) { 'abiertos' { 'feliz' } 'serio' { 'antojo' } default { if ($script:antojo -ge 100) { 'antojo' } else { 'main' } } }
        Actor-Pose 'A' $pose 0
    }
    if ($script:caras.Count -gt 0) {
        if (-not $cara) { $cara = @('cerrados', 'abiertos')[$Rnd.Next(2)] }
        $script:caraModo = $cara
    }
}

# frase importante: no la corta ninguna otra hasta que se ha escrito y ha dado tiempo a leerla
function Decir-Fijo($texto, $cara, $extra = 3000) {
    $script:twForzar = $true
    try { Decir $texto $cara } finally { $script:twForzar = $false }
    $ms = ([string]$texto).Length * 30 / [Math]::Max(1, $script:skin.Velocidad)
    $script:twBloqueo = [Environment]::TickCount + [int]$ms + $extra
}
function Saludo {
    $k = $script:skin
    if ($k.Estilo -eq 'teto' -and $Rnd.Next(2) -eq 0) {
        $h = (Get-Date).Hour
        if ($h -ge 6 -and $h -lt 13) { return '¡Good morning! ...es "buenos días" en inglés. ¡Buenos días!' }
        elseif ($h -ge 21 -or $h -lt 6) { return '¡Good night! ...ah, no, que acabas de llegar. ¡Buenas noches igual! ¿No deberías dormir?' }
    }
    if ($k.Estilo -eq 'web' -and $Rnd.Next(2) -eq 0) {
        $h = (Get-Date).Hour
        if ($h -lt 6) { return 'Son las tantas. Deberías dormir. Pero bueno, ¿qué abro?' }
        elseif ($h -lt 13) { return 'Buenos días. O eso dicen.' }
        elseif ($h -lt 20) { return 'Buenas tardes. ¿Qué toca ahora?' }
        else { return 'Buenas noches. Bueno, no tan buenas, sigues aquí.' }
    }
    return (Azar $k.Hola)
}

function Mensaje-Entrada($prev) {
    if ($prev -and $script:skin.AlVenirDe -and $script:skin.AlVenirDe[$prev]) { return $script:skin.AlVenirDe[$prev] }
    return (Saludo)
}

# lo que la skin actual opina de otra skin
function Opinion($nombre) {
    $k = $script:skin
    if ($nombre -eq $script:skinNombre) { return (Azar $k.Yo) }
    return (Azar $k.Opina[$nombre])
}
function Opinion-Azar {
    $otras = @($Skins.Keys | Where-Object { $_ -ne $script:skinNombre })
    return (Opinion (Azar $otras))
}

# ================= BOCADILLO CON TEXTO DESPLAZABLE =================
# El texto va dentro de una caja: si no cabe, sigue la última línea mientras se escribe,
# luego vuelve al principio y baja despacio. También se mueve con la rueda del ratón.
$script:caja = $null; $script:textoManual = $false; $script:leerT = 0
function Montar-Caja-Texto {
    $l = $script:status
    $c = New-Object CajaTexto
    $c.Location = $l.Location; $c.Size = $l.Size
    $c.BackColor = $l.BackColor; $c.BorderStyle = $l.BorderStyle
    $l.BorderStyle = 'None'
    $form.Controls.Remove($l)
    $l.Location = New-Object System.Drawing.Point(0, 0)
    $l.Size = New-Object System.Drawing.Size(($c.ClientSize.Width), ($c.ClientSize.Height))
    $l.BackColor = [System.Drawing.Color]::Transparent
    $c.Controls.Add($l)
    $c.Add_MouseWheel({ Desplazar-Texto $_.Delta })
    $c.Add_MouseEnter({ $this.Focus() })
    $l.Add_MouseEnter({ if ($script:caja) { [void]$script:caja.Focus() } })
    $l.Add_MouseWheel({ Desplazar-Texto $_.Delta })
    $c.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
    $form.Controls.Add($c)
    $script:caja = $c
}
function Ajustar-Texto {
    $c = $script:caja; $l = $script:status; if (-not $c -or -not $l) { return }
    $ancho = [Math]::Max(10, $c.ClientSize.Width - $l.Padding.Horizontal)
    if ($l.UseCompatibleTextRendering) {
        $g = $l.CreateGraphics(); $alto = [int][Math]::Ceiling($g.MeasureString(($l.Text + ' '), $l.Font, $ancho).Height); $g.Dispose()
    } else {
        $alto = [System.Windows.Forms.TextRenderer]::MeasureText(($l.Text + ' '), $l.Font, (New-Object System.Drawing.Size($ancho, 100000)), ([System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::TextBoxControl)).Height
    }
    $alto += $l.Padding.Vertical + 6
    $h = [Math]::Max($c.ClientSize.Height, $alto)
    if ($l.Width -ne $c.ClientSize.Width) { $l.Width = $c.ClientSize.Width }
    if ($l.Height -ne $h) { $l.Height = $h }
    if (-not $script:textoManual) { $l.Top = $c.ClientSize.Height - $h }
}
function Desplazar-Texto($delta) {
    $c = $script:caja; $l = $script:status; if (-not $c) { return }
    $script:textoManual = $true
    $paso = [int]($l.Font.Height * 1.2) * [Math]::Sign($delta)
    $l.Top = [int][Math]::Min(0, [Math]::Max($c.ClientSize.Height - $l.Height, $l.Top + $paso))
}
# cuando termina de escribirse un texto largo: vuelve al principio y baja despacio
function Leer-Texto($escribiendo) {
    $c = $script:caja; $l = $script:status
    if (-not $c -or $escribiendo -or $script:textoManual -or $l.Height -le $c.ClientSize.Height) { return }
    $script:leerT++
    if ($script:leerT -eq 45) { $l.Top = 0 }
    elseif ($script:leerT -gt 85 -and ($script:leerT % 2) -eq 0) {
        $min = $c.ClientSize.Height - $l.Height
        if ($l.Top -gt $min) { $l.Top = [Math]::Max($min, $l.Top - [Math]::Max(1, [int]$script:K)) }
    }
}
# ================= CARAS DEL ASISTENTE =================
function Img-Base {
    if ($script:skin.Estilo -eq 'kaiju' -and $script:kFin -and $script:kGanadora -eq 'Z') { return $null }
    if ($script:skin.Estilo -eq 'mew') {
        if (-not $script:gVivo) { return $null }
        if ($script:gFase2) { return $script:imgs.fase2 }
    }
    return $script:imgs.main
}
$caraTimer = New-Object System.Windows.Forms.Timer
$caraTimer.Add_Tick({ $caraTimer.Stop(); if ($script:pb) { $script:pb.Image = (Img-Base) } })
function Cara($clave, $ms) {
    if ($script:actorIds.Count -ge 1) { Actor-Pose $script:actorIds[0] $clave $ms; return }
    if (-not $script:pb -or -not $script:imgs[$clave]) { return }
    $tvTimer.Stop()
    $script:pb.Image = $script:imgs[$clave]
    $caraTimer.Stop(); $caraTimer.Interval = $ms; $caraTimer.Start()
}

# pequeño corte de señal en la tele de Static Miku
$script:tvPaso = 0
$tvTimer = New-Object System.Windows.Forms.Timer
$tvTimer.Interval = 50
$tvTimer.Add_Tick({
    $script:tvPaso--
    if ($script:tvPaso -le 0 -or -not $script:pb) {
        $tvTimer.Stop()
        if ($script:pb) { $script:pb.Image = (Img-Base) }
        return
    }
    Llenar-Ruido $script:tvRuido
    $script:pb.Invalidate()
})
function Corte-Senal($ticks) {
    if ($script:aj.Epilepsia) { return }   # modo seguro: sin estática
    if (-not $script:pb -or -not $script:tvRuido) { return }
    $caraTimer.Stop()
    $script:pb.Image = $script:tvRuido
    $script:tvPaso = $ticks
    $tvTimer.Start()
}

# ================= GUILLOTINA: VIDA Y FURIA =================
$script:gHP = 400; $script:gMax = 400; $script:gFase2 = $false; $script:gVivo = $true
$revTimer = New-Object System.Windows.Forms.Timer
$revTimer.Interval = 5000
$revTimer.Add_Tick({
    $revTimer.Stop()
    if ($script:skin.Estilo -ne 'mew') { return }
    $script:gHP = 400; $script:gMax = 400; $script:gFase2 = $false; $script:gVivo = $true
    if ($script:pb) { $script:pb.Image = (Img-Base) }
    $a = $script:actores['G']; if ($a) { $a.Visible = $true; $a.Alfa = 1.0; $a.Base = 'main'; Actor-Pose 'G' 'clic' 2600 }
    Sonido 'intro'; Sacudir $form 10
    Decir 'WMEW 99.9: ¡Guillotina ha vuelto, buscando venganza!'
    $form.Invalidate()
})
$script:gComidos = 0
function Golpe-Guillotina {
    if (-not $script:gVivo) { Decir '*Ya no está. Pero volverá.*'; return }
    $d = $Rnd.Next(15, 41)
    $script:gHP -= $d
    Actor-Golpe 'G'
    Flotante "-$d" $Rnd.Next(540, 620) $Rnd.Next(90, 130) (C 255 90 70) 32 'EdmundMcMillen_INTLv4'
    if (-not $script:gFase2 -and $script:gHP -le 200) {
        # igual que en el juego: se enfurece, cura 50 y gana 100 de vida máxima
        $script:gFase2 = $true; $script:gHP += 50; $script:gMax += 100
        $a = $script:actores['G']; if ($a) { $a.Base = 'furiosa' }
        Sonido 'furia'; Sonido 'intro'; Cara 'clic' 2600; Sacudir $form 14
        Flotante '¡FURIOSA!' 500 96 (C 255 60 40) 42 'EdmundMcMillen_INTLv4'
        Decir 'WMEW 99.9: ¡Está FURIOSA! ¡Recupera 50 de vida y crece todavía más!'
    } elseif ($script:gHP -le 0) {
        $script:gHP = 0; $script:gVivo = $false
        Sonido 'muere'
        if ($script:pb) { $caraTimer.Stop(); $script:pb.Image = $null }
        $a = $script:actores['G']; if ($a) { $a.Visible = $false }
        Flotante 'K.O.' 540 110 (C 255 60 50) 48 'EdmundMcMillen_INTLv4'
        Decir '*Guillotina cae rodando...* ¡La has derrotado! Por ahora.'
        $revTimer.Start()
    } else {
        if ($script:gFase2) { Sonido 'golpef' } else { Sonido 'golpe' }
        Cara 'herida' 1300
        Decir "-$d HP. $(Azar $script:skin.Clic)"
    }
    $form.Invalidate()
}
# ataques y gestos de Guillotina (en reposo o al abrir apps)
function Guillotina-Ataque($tipo, $texto) {
    if (-not $script:gVivo -or (Ocupado)) { return }
    switch ($tipo) {
        'come' {
            $script:gComidos++
            if ($script:gFase2) { Cara 'inhalaf' 2600 } else { Cara 'inhala' 2600 }
            Sonido 'comer'; Flotante '*ÑAM*' 470 100 (C 255 236 200) 30 'EdmundMcMillen_INTLv4'
        }
        'lanza' { Cara 'lanza' 2200; Sonido 'lanza'; Flotante '¡ALLÁ VA!' 520 90 (C 255 236 200) 26 'EdmundMcMillen_INTLv4' }
        'digiere' { Cara 'digiere' 2600; Sonido 'digiere'; Flotante '*BURP*' 560 110 (C 200 240 140) 28 'EdmundMcMillen_INTLv4' }
        'barriga' { Cara 'barriga' 2000; Sonido 'barriga'; Sacudir $form 12; Flotante '¡BUM!' 540 150 (C 255 120 60) 40 'EdmundMcMillen_INTLv4' }
    }
    if ($texto) { Decir $texto }
    $form.Invalidate()
}

# ================= MIKAELA: SNIPE, HITMARKERS, SMOKEBOMB Y DO THE DEW =================
$script:snApuntando = $false; $script:snCarga = 0; $script:snPos = New-Object System.Drawing.Point(95, 75)
$script:hits = New-Object System.Collections.ArrayList; $script:flash = 0
$script:hitsTotal = 0; $script:dew = 0; $script:lanzadas = 0

$fxTimer = New-Object System.Windows.Forms.Timer
$fxTimer.Interval = 40
$fxTimer.Add_Tick({
    for ($i = $script:hits.Count - 1; $i -ge 0; $i--) { $script:hits[$i].T--; if ($script:hits[$i].T -le 0) { $script:hits.RemoveAt($i) } }
    if ($script:flash -gt 0) { $script:flash-- }
    if ($script:pb) { $script:pb.Invalidate() }
    if ($script:hits.Count -eq 0 -and $script:flash -eq 0 -and -not $script:snApuntando) { $fxTimer.Stop() }
})
function Nuevo-Hit($x, $y) { [void]$script:hits.Add(@{ X = $x; Y = $y; T = 14 }); $fxTimer.Start() }

$snTimer = New-Object System.Windows.Forms.Timer
$snTimer.Interval = 100
$snTimer.Add_Tick({
    $script:snCarga++
    if ($script:snCarga -eq 20) { Sonido 'carga'; Decir 'CHARGED.' }
    if ($script:snCarga -eq 60) { Sonido 'sobrecarga'; Decir 'OVERCHARGED. Esto va a doler.' }
    $form.Invalidate()
})
function Snipe-Inicio {
    if ((Ocupado) -or $script:snApuntando) { return }
    $script:snApuntando = $true; $script:snCarga = 0
    Sonido 'apuntar'; Decir 'Apuntando... (suelta para disparar)'
    $snTimer.Start(); $fxTimer.Start()
}
function Snipe-Disparo {
    if (-not $script:snApuntando) { return }
    $snTimer.Stop(); $script:snApuntando = $false
    # igual que en el juego: 0.5s sin cargar, 1.5s cargado (2s) y 2.5s sobrecargado (6s)
    if ($script:snCarga -ge 60) { $stun = '2.5'; Sonido 'disparoMax' } elseif ($script:snCarga -ge 20) { $stun = '1.5'; Sonido 'disparo' } else { $stun = '0.5'; Sonido 'disparo' }
    Nuevo-Hit $script:snPos.X $script:snPos.Y
    $script:flash = 4; $script:hitsTotal++
    Decir "¡Stun de ${stun}s! $(Azar $script:skin.Clic)"
    $form.Invalidate()
}
$humoTimer = New-Object System.Windows.Forms.Timer
$humoTimer.Interval = 3000
$humoTimer.Add_Tick({ $humoTimer.Stop(); $form.Opacity = (Opacidad-Base) })

# ================= ZODIAC: REVÓLVER DE 6 BALAS =================
$script:balas = 6; $script:disparos = 0; $script:rotTambor = 0.0; $script:fogonazo = 0
$script:agujeros2 = New-Object System.Collections.ArrayList
function Zodiac-Disparo {
    if ($script:balas -gt 0) {
        $script:balas--; $script:disparos++; $script:rotTambor += 60; $script:fogonazo = 4
        Sonido 'bang'; if ($Rnd.Next(2) -eq 0) { Sonido 'grito' }
        Cara 'clic' 1300; Sacudir $form 5
        # agujero de bala en algún sitio del paisaje
        [void]$script:agujeros2.Add(@{ X = [double]$Rnd.Next(410, 740); Y = [double]$Rnd.Next(70, 240); T = 220 })
        Flotante '¡BANG!' $Rnd.Next(440, 640) $Rnd.Next(70, 120) (C 255 220 90) 34 'EdmundMcMillen_INTLv4'
        $form.Invalidate(); return $true
    }
    Cara 'vacio' 1800; Sonido 'vacio'
    Flotante '*click*' 560 100 (C 250 236 205) 24 'EdmundMcMillen_INTLv4'
    return $false
}
# ---- duelo al mediodía: cuando sale "DRAW!", haz clic en Zodiac antes de que dispare ----
$script:duelo = $null; $script:duelosG = 0; $script:duelosP = 0
function Zodiac-Duelo {
    if ($script:duelo -or (Ocupado)) { return }
    $script:duelo = @{ Fase = 'espera'; T = $Rnd.Next(30, 80); Ini = 0 }
    Sonido 'viento'; Cara 'pose' 0
    Decir '¡DUELO! Cuando salga "DRAW!", haz clic en mí. Ni un segundo antes, forastero.'
    $form.Invalidate()
}
function Zodiac-Duelo-Tick {
    $d = $script:duelo
    if ($d.Fase -eq 'espera') {
        $d.T--
        if ($d.T -le 0) { $d.Fase = 'draw'; $d.T = 0; $d.Ini = [Environment]::TickCount; Sonido 'grito'; Sacudir $form 3 }
    } elseif ($d.Fase -eq 'draw') {
        $d.T++
        # Zodiac desenfunda a los 0,9 segundos
        if (([Environment]::TickCount - $d.Ini) -gt 900) { Zodiac-Duelo-Fin 'lento' }
    }
}
function Zodiac-Duelo-Fin($como) {
    $d = $script:duelo; $script:duelo = $null
    switch ($como) {
        'gana' {
            $ms = [Environment]::TickCount - $d.Ini; $script:duelosG++
            Sonido 'bang'; Sonido 'dolor'; Cara 'muere' 2600; Sacudir $form 6; $script:fogonazo = 4
            Flotante ("¡GANASTE!  {0:0.00} s" -f ($ms / 1000.0)) 470 90 (C 255 214 90) 30 'EdmundMcMillen_INTLv4'
            $l = if ($ms -lt 300) { 'Eso ha sido... imposible. ¿Eres un fantasma?' } elseif ($ms -lt 450) { 'Rápido. Muy rápido. Me caigo con estilo.' } else { 'Por los pelos, forastero. Por los pelos.' }
            Decir-Fijo ("*Cae al suelo muy dramáticamente.* $l")
        }
        'lento' {
            $script:duelosP++; $script:disparos++; $script:fogonazo = 4
            Sonido 'bang'; Sonido 'loco'; Cara 'clic' 1600; Sacudir $form 8
            [void]$script:agujeros2.Add(@{ X = [double]$Rnd.Next(420, 520); Y = [double]$Rnd.Next(80, 220); T = 220 })
            Flotante '¡BANG!' 520 90 (C 255 220 90) 34 'EdmundMcMillen_INTLv4'
            Decir (Azar @('Demasiado lento, forastero. *Sopla el humo del cañón.*', '*BANG* En el desierto, el lento se queda sin sombrero.', 'Te has dormido. Yo no duermo. Nunca. Por eso estoy así.'))
        }
        'trampa' {
            $script:duelosP++; $script:disparos++; $script:fogonazo = 4
            Sonido 'bang'; Sonido 'grito'; Cara 'clic' 1600; Sacudir $form 10
            Flotante '¡TRAMPOSO!' 450 90 (C 235 46 34) 32 'EdmundMcMillen_INTLv4'
            Decir '¡TRAMPOSO! Aún no había salido DRAW. *BANG* Eso por listo.'
        }
    }
    $form.Invalidate()
}
function Zodiac-Clic {
    $k = $script:skin
    if ($script:duelo) { if ($script:duelo.Fase -eq 'draw') { Zodiac-Duelo-Fin 'gana' } else { Zodiac-Duelo-Fin 'trampa' }; return }
    if ($script:balas -eq 6 -and $Rnd.Next(3) -eq 0) { Zodiac-Duelo; return }
    if ($script:balas -lt 6) {
        $script:balas = 6; $script:rotTambor += 180
        Cara 'recarga' 1500; Sonido 'recarga'; Sonido 'recargav'
        Decir '*Recarga el revólver.* Seis balas. Que empiece el baile.'
        $form.Invalidate()
    } else { Cara 'pose' 3000; Sonido 'loco'; Decir (Azar $k.Clic) }
}
function Zodiac-Mover {
    if ($script:duelo) { Zodiac-Duelo-Fin $(if ($script:duelo.Fase -eq 'draw') { 'lento' } else { 'trampa' }); return }
    if (Zodiac-Disparo) { Decir '¡NO TE MUEVAS! *BANG*' } else { Decir '¡NO TE MUEVAS! *click*... ¿sin balas? Qué vergüenza.' }
}

# ================= VELVET: TELARAÑAS =================
$script:telarana = $null; $script:telas = 0
$telTimer = New-Object System.Windows.Forms.Timer
$telTimer.Interval = 25000
$telTimer.Add_Tick({ $telTimer.Stop(); $script:telarana = $null; if ($script:grid) { foreach ($c in $script:grid.Controls) { $c.Invalidate() } } })
function Velvet-Escupir {
    $btns = @($script:grid.Controls | Where-Object { $_.Tag -is [hashtable] })
    if ($btns.Count -eq 0) { return $false }
    $b = $btns[$Rnd.Next($btns.Count)]
    $script:telarana = $b.Tag; $script:telas++
    foreach ($c in $script:grid.Controls) { $c.Invalidate() }
    $telTimer.Stop(); $telTimer.Start()
    $form.Invalidate()
    return $b.Text
}

# ================= DUNE: HAMBRE =================
$script:hambre = 0
$hambreTimer = New-Object System.Windows.Forms.Timer
$hambreTimer.Interval = 4000
$hambreTimer.Add_Tick({
    if ((Ocupado) -or -not $script:skin) { return }
    # la fe del culto baja sola con el tiempo
    if ($script:skin.Estilo -eq 'culto') {
        $antes = $script:fe; $script:fe = [Math]::Max(0, $script:fe - 1)
        if ($antes -ge 25 -and $script:fe -lt 25 -and -not $script:discutiendo) { Sonido 'campana'; Decir 'Cabra: La fe está bajando. Hay disidentes. Abre algo, que se nos rebelan.' }
        $form.Invalidate(); return
    }
    # a Averi le entran ganas de un sándwich de pollo
    if ($script:skin.Estilo -eq 'zorro') {
        $antes = $script:antojo; $script:antojo = [Math]::Min(100, $script:antojo + 3)
        if ($antes -lt 100 -and $script:antojo -ge 100 -and -not $script:discutiendo) { Decir '¿...huele a pollo? No huele. Pero me apetece un sándwich. (haz clic en mí)' 'serio' }
        $form.Invalidate(); return
    }
    if (-not $script:skin.Hambre) { return }
    $antes = $script:hambre
    $script:hambre = [Math]::Min(100, $script:hambre + 4)
    if ($antes -lt 100 -and $script:hambre -ge 100 -and -not $script:discutiendo) { Decir 'GRRRGH... DUNE TENER HAMBRE... (haz clic en Dune para darle de comer)' }
    $form.Invalidate()
})
function Dune-Comer {
    $script:hambre = 0; $script:salto = 10
    Decir (Azar $script:skin.Clic)
    $form.Invalidate()
}

# ================= PERSONAJES DIBUJADOS EN EL PANEL (skins nuevas) =================
# Los personajes se pintan directamente sobre el fondo, grandes y con efectos encima.
# Cada GIF se anima fotograma a fotograma con su propio ritmo.
$script:actores = [ordered]@{}; $script:actorIds = @()
$script:flotantes = New-Object System.Collections.ArrayList
$script:bmpEscena = $null
function Gif-Info($img) {
    $n = 1; $del = @(100)
    try {
        $dim = New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])
        $n = $img.GetFrameCount($dim)
        if ($n -gt 1) {
            $pi = $img.GetPropertyItem(0x5100); $del = New-Object 'int[]' $n
            for ($i = 0; $i -lt $n; $i++) { $d = [BitConverter]::ToInt32($pi.Value, $i * 4) * 10; if ($d -lt 20) { $d = 100 }; $del[$i] = $d }
        }
    } catch { $n = 1; $del = @(100) }
    return @{ N = $n; Del = $del }
}
function Nuevo-Actor($def) {
    $imgs = @{ main = (Cargar-Img $def.Gif) }
    if ($def.Extra) { foreach ($e in $def.Extra.Keys) { $imgs[$e] = Cargar-Img $def.Extra[$e] } }
    $info = @{}; foreach ($e in @($imgs.Keys)) { if ($imgs[$e]) { $info[$e] = Gif-Info $imgs[$e] } }
    # animaciones hechas con una tira de fotogramas (PNG con transparencia)
    $tiras = @{}
    if ($def.Tiras) {
        foreach ($e in $def.Tiras.Keys) {
            $tt = $def.Tiras[$e]; $fr = Cortar-Tira $tt.Archivo $tt.Frames $tt.Orden
            if ($fr) { $tiras[$e] = $fr; $imgs[$e] = $fr[0]; $del = New-Object 'int[]' $fr.Count; for ($i = 0; $i -lt $fr.Count; $i++) { $del[$i] = $tt.Delay }; $info[$e] = @{ N = $fr.Count; Del = $del } }
        }
    }
    $script:actores[$def.Id] = @{ Id = $def.Id; Imgs = $imgs; Info = $info; Pose = 'main'; Frame = 0; Acc = 0; Hasta = 0; Rect = $def.Rect
        Visible = $true; Alfa = 1.0; Flash = 0; Temblor = 0; OX = 0; OY = 0; Llenar = [bool]$def.Llenar; Base = 'main'; Tiras = $tiras; Respira = [bool]$def.Respira; Baila = [bool]$def.Baila; Dash = 0 }
    $script:actorIds += $def.Id
}
function Quitar-Actores {
    foreach ($a in @($script:actores.Values)) {
        foreach ($e in @($a.Imgs.Keys)) { if ($a.Imgs[$e] -and -not $a.Tiras.ContainsKey($e)) { $a.Imgs[$e].Dispose() } }
        foreach ($fr in @($a.Tiras.Values)) { foreach ($im in $fr) { $im.Dispose() } }
    }
    $script:actores = [ordered]@{}; $script:actorIds = @(); $script:flotantes.Clear()
}
function Cortar-Tira($ruta, $n, $orden) {
    $t = Cargar-Img $ruta; if (-not $t) { return $null }
    $w = [int]($t.Width / $n); $h = $t.Height
    if (-not $orden) { $orden = 0..($n - 1) }
    $res = New-Object System.Collections.ArrayList
    foreach ($i in $orden) {
        $b = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
        $g = [System.Drawing.Graphics]::FromImage($b)
        $g.DrawImage($t, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)), ($i * $w), 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose(); [void]$res.Add($b)
    }
    $t.Dispose(); return ,$res.ToArray()
}
function Seleccionar-Frame($a) {
    if ($a.Tiras.ContainsKey($a.Pose)) { $a.Imgs[$a.Pose] = $a.Tiras[$a.Pose][$a.Frame]; return }
    $img = $a.Imgs[$a.Pose]; $inf = $a.Info[$a.Pose]
    if ($img -and $inf.N -gt 1) { [void]$img.SelectActiveFrame((New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])), $a.Frame) }
}
function Invalidar-Escena {
    $Z = $script:K
    $alto = if ($script:skin -and $script:skin.Alto) { [Math]::Max(200, $script:skin.Alto - 100) } else { 200 }
    # desde un poco más arriba de la escena, para que los saltos no dejen cabezas cortadas bajo la barra
    $form.Invalidate((New-Object System.Drawing.Rectangle([int](400 * $Z), [int](34 * $Z), [int](($form.ClientSize.Width / $Z - 400) * $Z), [int](($alto + 22) * $Z))))
}
function Actor-Pose($id, $pose, $ms) {
    $a = $script:actores[$id]; if (-not $a -or -not $a.Imgs[$pose]) { return }
    $a.Pose = $pose; $a.Frame = 0; $a.Acc = 0
    Seleccionar-Frame $a
    $a.Hasta = if ($ms -gt 0) { [Environment]::TickCount + $ms } else { 0 }
    Invalidar-Escena
}
function Actor-Golpe($id) { $a = $script:actores[$id]; if ($a) { $a.Flash = 6; $a.Temblor = 9 } }
# texto que sube y se desvanece (daño, balidos, corazones...)
function Flotante($txt, $x, $y, $col, $tam, $fuente) {
    [void]$script:flotantes.Add(@{ Txt = $txt; X = [double]$x; Y = [double]$y; T = 30; Col = $col; Tam = $tam; F = $(if ($fuente) { $fuente } else { 'Impact' }) })
}
function Texto-Contorno($g, $txt, $fuente, $tam, $x, $y, $color, $grosor, $alfa = 255) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, [float]$tam, (New-Object System.Drawing.PointF([float]$x, [float]$y)), [System.Drawing.StringFormat]::GenericDefault)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alfa, 0, 0, 0), [float]$grosor); $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $path); $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alfa, $color.R, $color.G, $color.B))), $path)
    $pen.Dispose(); $path.Dispose()
}
function Ancho-Texto($txt, $fuente, $tam) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($txt, (Familia $fuente), 0, [float]$tam, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericDefault)
    $w = $path.GetBounds().Right; $path.Dispose(); return $w
}
function Pintar-Actor($g, $a) {
    if (-not $a.Visible) { return }
    $img = $a.Imgs[$a.Pose]; if (-not $img) { return }
    $r = $a.Rect
    if ($a.Llenar) {
        # rellena el recuadro recortando lo que sobra (fotos)
        $s = [Math]::Max($r[2] / $img.Width, $r[3] / $img.Height)
        $sw = $r[2] / $s; $sh = $r[3] / $s
        $src = New-Object System.Drawing.RectangleF([float](($img.Width - $sw) / 2), [float](($img.Height - $sh) / 2), [float]$sw, [float]$sh)
        $g.DrawImage($img, (New-Object System.Drawing.RectangleF([float]$r[0], [float]$r[1], [float]$r[2], [float]$r[3])), $src, [System.Drawing.GraphicsUnit]::Pixel)
        return
    }
    $s = [Math]::Min($r[2] / $img.Width, $r[3] / $img.Height)
    $w = $img.Width * $s; $h = $img.Height * $s
    $x = $r[0] + ($r[2] - $w) / 2 + $a.OX; $y = $r[1] + $r[3] - $h + $a.OY
    if ($a.Flash -gt 0 -or $a.Alfa -lt 1) {
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        if ($a.Flash -gt 0) { $b = [float](0.7 * $a.Flash / 6); $cm.Matrix40 = $b; $cm.Matrix41 = $b; $cm.Matrix42 = $b }
        $cm.Matrix33 = [float]$a.Alfa
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle([int]$x, [int]$y, [int]$w, [int]$h)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $ia.Dispose()
    } else { $g.DrawImage($img, (New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h))) }
}
function Pintar-Actores($g) {
    $modo = $g.InterpolationMode; $g.InterpolationMode = 'HighQualityBilinear'
    foreach ($a in @($script:actores.Values)) { Pintar-Actor $g $a }
    $g.InterpolationMode = $modo
}
function Pintar-Flotantes($g) {
    foreach ($f in $script:flotantes) {
        $alfa = [int][Math]::Min(255, $f.T * 22)
        if ($f.Txt -eq '<3') { Dibujar-Corazon $g $f.X $f.Y $f.Tam $alfa }
        else { Texto-Contorno $g $f.Txt $f.F $f.Tam $f.X $f.Y $f.Col ([Math]::Max(3, $f.Tam / 5)) $alfa }
    }
}
# hace que la Cara/Cara2 de siempre muevan a los personajes dibujados
function Cara2($clave, $ms) { if ($script:actorIds.Count -ge 2) { Actor-Pose $script:actorIds[1] $clave $ms } }
$actTimer = New-Object System.Windows.Forms.Timer
$actTimer.Interval = 40
$script:ultimoTick = [Environment]::TickCount
$actTimer.Add_Tick({
    Sin-Destellos
    $ahora = [Environment]::TickCount; $dt = $ahora - $script:ultimoTick; $script:ultimoTick = $ahora
    if ($dt -gt 200) { $dt = 200 }
    if ($script:actores.Count -eq 0) { return }
    $cambio = $false
    foreach ($a in @($script:actores.Values)) {
        if ($a.Hasta -gt 0 -and $ahora -ge $a.Hasta) { $a.Hasta = 0; $a.Pose = $a.Base; $a.Frame = 0; $a.Acc = 0; Seleccionar-Frame $a; $cambio = $true }
        $inf = $a.Info[$a.Pose]
        if ($inf -and $inf.N -gt 1 -and $a.Visible) {
            $a.Acc += $dt; $avanza = $false
            while ($a.Acc -ge $inf.Del[$a.Frame]) { $a.Acc -= $inf.Del[$a.Frame]; $a.Frame = ($a.Frame + 1) % $inf.N; $avanza = $true }
            if ($avanza) { Seleccionar-Frame $a; $cambio = $true }
        }
        if ($a.Flash -gt 0) { $a.Flash--; $cambio = $true }
        if ($a.Temblor -gt 0) { $a.Temblor--; $a.OX = $Rnd.Next(-5, 6) * [Math]::Min(1, $a.Temblor); $a.OY = $Rnd.Next(-3, 4) * [Math]::Min(1, $a.Temblor); $cambio = $true }
        elseif ($a.Dash -gt 0) { $a.Dash--; $a.OX = - [Math]::Sin(($a.Dash / 14.0) * [Math]::PI) * 80; $cambio = $true }
        elseif ($a.Salto -gt 0) { $a.Salto--; $a.OX = 0; $a.OY = - [Math]::Sin(($a.Salto / 12.0) * [Math]::PI) * 24; $cambio = $true }
        elseif ($a.Baila) { $tb = $ahora / 1000.0; $a.OY = - [Math]::Abs([Math]::Sin($tb * 3.4)) * 8; $a.OX = [Math]::Sin($tb * 1.7) * 6; $cambio = $true }
        elseif ($a.Respira) { $a.OY = [Math]::Sin($ahora / 650.0) * 3; $a.OX = [Math]::Sin($ahora / 1700.0) * 2; $cambio = $true }
    }
    if ($script:flotantes.Count -gt 0) {
        for ($i = $script:flotantes.Count - 1; $i -ge 0; $i--) { $f = $script:flotantes[$i]; $f.T--; $f.Y -= 1.3; if ($f.T -le 0) { $script:flotantes.RemoveAt($i) } }
        $cambio = $true
    }
    if ($cambio) { Invalidar-Escena }
})
$script:fuentes = $null
function Existe-Fuente($n) {
    if (-not $script:fuentes) { $script:fuentes = @((New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name }) }
    return ($script:fuentes -contains $n)
}

# ================= CORDERO Y CABRA: FE DEL CULTO Y RITUALES =================
$script:fe = 60; $script:seguidores = 0; $script:ritualFx = 0
function Cordero-Clic {
    Sonido 'balido'; Cara 'clic' 1800
    Flotante '¡BEEE!' 470 70 (C 255 250 240) 22 'Palatino Linotype'
    $script:fe = [Math]::Min(100, $script:fe + 2)
    Decir (Azar $script:skin.Clic); $form.Invalidate()
}
function Cabra-Clic {
    if ($Rnd.Next(2) -eq 0) {
        Sonido 'grito'; Cara2 'grito' 2400; Actor-Golpe 'G'
        Flotante '¡AAAAH!' 616 70 (C 190 130 240) 24 'Palatino Linotype'
    } else {
        Sonido 'risa'; Cara2 'risa' 2800
        Flotante 'JA JA JA' 620 74 (C 190 130 240) 18 'Palatino Linotype'
    }
    Decir (Azar $script:skin.Clic2)
}
# cada 5 apps abiertas: ritual con tentáculos
function Culto-Ritual {
    $script:ritualFx = 44; $script:fe = [Math]::Min(100, $script:fe + 20)
    Sonido 'ritual'; Cara 'baile' 3200; Cara2 'risa' 3200
    Flotante '¡RITUAL!' 520 90 (C 255 70 80) 34 'Palatino Linotype'
    Decir "¡RITUAL! $($script:seguidores) seguidores. Cabra: *Salen tentáculos del suelo.* La fe sube. Y el miedo."
    $form.Invalidate()
}
# la Cabra habla con sus voces reales del juego; el Cordero bala
function Voz-Culto($texto) {
    if ($texto -match '^Cabra:') { if ($texto -match '¡|!') { Sonido 'enfado' } else { Sonido 'voz' } }
    elseif ($texto -match '^Cordero:' -and $Rnd.Next(2) -eq 0) { Sonido 'balido' }
}

# ================= PYROPHINA Y ZARATANA: PELEA DE KAIJUS =================
$script:kHP = @{ P = 1000; Z = 1000 }; $script:kFase = @{ P = $false; Z = $false }; $script:kFin = $false; $script:kGanadora = ''
$script:collares = @{ P = 0; Z = 0 }
$script:particulas = New-Object System.Collections.ArrayList
$kRevTimer = New-Object System.Windows.Forms.Timer
$kRevTimer.Interval = 7000
$kRevTimer.Add_Tick({
    $kRevTimer.Stop()
    if ($script:skin.Estilo -ne 'kaiju') { return }
    Kaiju-Reiniciar
    Sonido 'intro'
    Decir 'WMEW 99.9: Steven las ha vuelto a invocar. ¡Segundo asalto!'
    $form.Invalidate()
})
function Kaiju-Reiniciar {
    $script:kHP = @{ P = 1000; Z = 1000 }; $script:kFase = @{ P = $false; Z = $false }; $script:kFin = $false; $script:kGanadora = ''
    $script:particulas.Clear()
    foreach ($a in @($script:actores.Values)) { $a.Visible = $true; $a.Alfa = 1.0 }
    Invalidar-Escena
}
function Centro-Kaiju($id) { $a = $script:actores[$id]; if (-not $a) { return @(500, 150) }; return @(($a.Rect[0] + $a.Rect[2] / 2), ($a.Rect[1] + $a.Rect[3] * 0.45)) }
# una kaiju ataca a la otra ('P' = Pyrophina, 'Z' = Zaratana). Con 500 o menos entran en su fase 2, como en el juego.
function Kaiju-Ataque($q, $texto) {
    if (Ocupado) { return }
    if ($script:kFin) { Decir 'WMEW 99.9: La pelea ha terminado. Steven las está volviendo a invocar...'; return }
    $obj = if ($q -eq 'P') { 'Z' } else { 'P' }
    $dmg = $Rnd.Next(45, 111); if ($script:kFase[$q]) { $dmg += 30 }
    $co = Centro-Kaiju $obj; $ca = Centro-Kaiju $q
    if ($q -eq 'P') {
        if ($Rnd.Next(3) -eq 0) {
            Cara 'fuego' 2600; Sonido 'pfuego'; $msg = "Pyrophina: ¡AAARGH! *Aliento de fuego.* Zaratana pierde $dmg."
            # chorro de fuego desde la boca de Pyrophina hasta Zaratana
            for ($i = 0; $i -lt 34; $i++) { $t = $Rnd.NextDouble(); [void]$script:particulas.Add(@{ T = 'f'; D = $i; X = [double]($ca[0] + 40); Y = [double]($ca[1] - 30); VX = ($co[0] - $ca[0] - 40) / 14.0 + ($Rnd.NextDouble() - 0.5) * 2; VY = ($co[1] - $ca[1] + 30) / 14.0 + ($Rnd.NextDouble() - 0.5) * 3; V = 16 }) }
        }
        else { Cara 'ataque' 1800; Sonido 'pataque'; $msg = "Pyrophina: *Zarpazo y lanzamiento.* Zaratana pierde $dmg." }
    } else {
        if ($Rnd.Next(3) -eq 0) {
            Cara2 'meteoros' 2600; Sonido 'zmeteoros'; $msg = "Zaratana: *Bombardeo de meteoritos.* Pyrophina pierde $dmg."
            # meteoritos que caen sobre Pyrophina
            for ($i = 0; $i -lt 6; $i++) { $tx = $co[0] + $Rnd.Next(-50, 51); [void]$script:particulas.Add(@{ T = 'm'; D = $i * 4; X = [double]($tx - 90); Y = -20.0; VX = 5.0; VY = 9.0; V = [int](($co[1] + 40) / 9) }) }
        }
        else { Cara2 'ataque' 1500; Sonido 'zataque'; $msg = "Zaratana: ¡GRRRR, GRRRRR! *Embestida.* Pyrophina pierde $dmg." }
    }
    if ($texto) { $msg = "$texto (-$dmg)" }
    $script:kHP[$obj] = $script:kHP[$obj] - $dmg
    Actor-Golpe $obj
    Flotante "-$dmg" ($co[0] - 18) ($co[1] - 70) $(if ($q -eq 'P') { (C 255 150 40) } else { (C 200 190 255) }) 30 'EdmundMcMillen_INTLv4'
    Sacudir $form 6
    if ($script:kHP[$obj] -le 0) {
        $script:kHP[$obj] = 0; $script:kFin = $true; $script:kGanadora = $q; $script:collares[$q]++
        $script:particulas.Clear()
        $perd = $script:actores[$obj]; if ($perd) { $perd.Alfa = 0.25; $perd.Hasta = 0; $perd.Pose = 'main' }
        Flotante 'K.O.' ($co[0] - 30) ($co[1] - 40) (C 255 60 50) 40 'EdmundMcMillen_INTLv4'
        if ($q -eq 'P') { Cara 'gana' 6500; Sonido 'pgana'; $msg = 'WMEW 99.9: ¡PYROPHINA GANA! Te da las gracias... y su collar.' }
        else { Cara2 'gana' 6500; Sonido 'zgana'; $msg = 'WMEW 99.9: ¡ZARATANA GANA! Te da las gracias... y su collar.' }
        $kRevTimer.Stop(); $kRevTimer.Start()
    } elseif (-not $script:kFase[$obj] -and $script:kHP[$obj] -le 500) {
        $script:kFase[$obj] = $true
        if ($obj -eq 'P') { Sonido 'pruge'; $msg = 'WMEW 99.9: ¡Pyrophina está a media vida! ¡Desata la TORMENTA DE FUEGO!' }
        else { Sonido 'zruge'; $msg = 'WMEW 99.9: ¡Zaratana está a media vida! ¡Desata el METEORNADO!' }
    }
    Decir $msg
    $form.Invalidate()
}
# brasas (tormenta de fuego) y meteoritos (meteornado) en el fondo
function Kaiju-Particulas {
    $Z = $script:K; $W = [Math]::Max(700, $form.ClientSize.Width / $Z)
    # tormenta de fuego (brasas) y meteornado (meteoritos) mientras dure la fase 2
    if (-not $script:kFin) {
        if ($script:kFase.P -and $Rnd.Next(2) -eq 0) { [void]$script:particulas.Add(@{ T = 'b'; D = 0; X = [double]$Rnd.Next(380, [int]$W); Y = 250.0; VX = ($Rnd.NextDouble() - 0.5) * 2; VY = -1.5 - $Rnd.NextDouble() * 2.5; V = 60 }) }
        if ($script:kFase.Z -and $Rnd.Next(9) -eq 0) { [void]$script:particulas.Add(@{ T = 'm'; D = 0; X = [double]$Rnd.Next(300, [int]$W - 60); Y = -20.0; VX = 4.0; VY = 7.0; V = 40 }) }
    }
    if ($script:particulas.Count -gt 0) {
        for ($i = $script:particulas.Count - 1; $i -ge 0; $i--) {
            $p = $script:particulas[$i]
            if ($p.D -gt 0) { $p.D--; continue }
            $p.X += $p.VX; $p.Y += $p.VY; $p.V--
            if ($p.V -le 0 -or $p.Y -gt 330) {
                if ($p.T -eq 'm' -and $p.Y -gt 60 -and $p.Y -lt 260) { Sonido 'zmeteoro'; for ($j = 0; $j -lt 5; $j++) { [void]$script:particulas.Add(@{ T = 'p'; D = 0; X = $p.X; Y = $p.Y; VX = ($Rnd.NextDouble() - 0.5) * 6; VY = -$Rnd.NextDouble() * 4; V = 10 }) } }
                $script:particulas.RemoveAt($i)
            }
        }
        Invalidar-Escena
    }
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](270 * $Z), [int](200 * $Z), [int](30 * $Z))))
}
function Pintar-Particulas($g) {
    foreach ($p in $script:particulas) {
        if ($p.D -gt 0) { continue }
        switch ($p.T) {
            'b' { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $p.V * 5), 255, (110 + ($p.V % 4) * 30), 30))), [float]$p.X, [float]$p.Y, 4, 4) }
            'f' {
                $s = 8 + (16 - $p.V) * 2.2; $al = [Math]::Max(0, [Math]::Min(230, $p.V * 16))
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 255, 90, 20))), [float]($p.X - $s / 2), [float]($p.Y - $s / 2), [float]$s, [float]$s)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 255, 230, 120))), [float]($p.X - $s / 4), [float]($p.Y - $s / 4), [float]($s / 2), [float]($s / 2))
            }
            'm' {
                $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, 255, 170, 80), 4)), [float]($p.X - $p.VX * 5), [float]($p.Y - $p.VY * 5), [float]$p.X, [float]$p.Y)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 120 112 124))), [float]($p.X - 7), [float]($p.Y - 7), 15, 15)
                $g.DrawEllipse((New-Object System.Drawing.Pen((C 40 36 44), 2)), [float]($p.X - 7), [float]($p.Y - 7), 15, 15)
            }
            'p' { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $p.V * 25), 150, 140, 150))), [float]$p.X, [float]$p.Y, 6, 6) }
        }
    }
}
# barra de vida de jefe con nombre, al estilo de Mewgenics
function Vida-Kaiju($g, $nombre, $hp, $x, $y, $w, $col, $fase2) {
    $placa = Ruta-Redonda ($x - 2) ($y - 2) ($w + 4) 22 10
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 22, 14, 16))), $placa)
    $g.DrawPath((New-Object System.Drawing.Pen((C 20 10 10), 2.5)), $placa); $placa.Dispose()
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 22 22))), ($x + 3), ($y + 3), ($w - 6), 14)
    $c = if ($fase2) { [System.Drawing.Color]::FromArgb(255, [Math]::Min(255, $col.R + 30), [Math]::Min(255, $col.G + 50), [Math]::Min(255, $col.B + 20)) } else { $col }
    $ancho = [int](($w - 6) * [Math]::Max(0, $hp) / 1000)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), ($x + 3), ($y + 3), $ancho, 14)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 255, 255))), ($x + 3), ($y + 3), $ancho, 5)
    $txt = if ($hp -le 0) { "$nombre  K.O." } elseif ($fase2) { "¡$nombre!  $hp" } else { "$nombre  $hp" }
    Texto-Contorno $g $txt 'EdmundMcMillen_INTLv4' 13 ($x + 6) ($y + 1) (C 255 250 235) 3
}

# ================= AVERI: ANTOJO DE SÁNDWICH Y CORAZONES =================
$script:antojo = 0
function Nuevo-Corazon {
    $a = $script:actores['A']; if (-not $a) { return }
    $r = $a.Rect
    Flotante '<3' ($r[0] + $Rnd.Next(20, $r[2] - 20)) ($r[1] + $r[3] - $Rnd.Next(10, 50)) $null $Rnd.Next(9, 15)
}
function Dibujar-Corazon($g, $x, $y, $s, $alfa) {
    $x = [float]$x; $y = [float]$y; $s = [float]$s
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier($x, ($y + $s * 0.3), $x, ($y - $s * 0.3), ($x - $s * 1.1), ($y - $s * 0.3), ($x - $s * 1.1), ($y + $s * 0.35))
    $p.AddBezier(($x - $s * 1.1), ($y + $s * 0.35), ($x - $s * 1.1), ($y + $s * 0.8), ($x - $s * 0.3), ($y + $s * 1.0), $x, ($y + $s * 1.35))
    $p.AddBezier($x, ($y + $s * 1.35), ($x + $s * 0.3), ($y + $s * 1.0), ($x + $s * 1.1), ($y + $s * 0.8), ($x + $s * 1.1), ($y + $s * 0.35))
    $p.AddBezier(($x + $s * 1.1), ($y + $s * 0.35), ($x + $s * 1.1), ($y - $s * 0.3), $x, ($y - $s * 0.3), $x, ($y + $s * 0.3))
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alfa, 240, 80, 110))), $p)
    $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alfa, 120, 30, 50), 1.5)), $p)
    $p.Dispose()
}
function Dibujar-Sandwich($g, $x, $y, $s) {
    $w = 32 * $s; $l = $x - $w / 2
    $lin = New-Object System.Drawing.Pen((C 110 60 30), [float](1.5 * $s))
    $pan = New-Object System.Drawing.SolidBrush((C 238 196 120))
    $r = Ruta-Redonda $l ($y + 14 * $s) $w (6 * $s) (4 * $s); $g.FillPath($pan, $r); $g.DrawPath($lin, $r); $r.Dispose()
    $r = Ruta-Redonda ($l + 1 * $s) ($y + 9 * $s) ($w - 2 * $s) (6 * $s) (4 * $s); $g.FillPath((New-Object System.Drawing.SolidBrush((C 214 140 80))), $r); $g.DrawPath($lin, $r); $r.Dispose()
    $pts = for ($i = 0; $i -le 8; $i++) { New-Object System.Drawing.PointF([float]($l + $i * $w / 8), [float]($y + 8 * $s + (($i % 2) * 3 - 1.5) * $s)) }
    $g.DrawLines((New-Object System.Drawing.Pen((C 110 180 70), [float](3 * $s))), [System.Drawing.PointF[]]$pts)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddArc([float]$l, [float]($y - 4 * $s), [float]$w, [float](22 * $s), 180, 180); $p.CloseFigure()
    $g.FillPath($pan, $p); $g.DrawPath($lin, $p); $p.Dispose()
    foreach ($sx in @(0.3, 0.5, 0.7)) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 245 220))), [float]($l + $w * $sx - 1.5 * $s), [float]$y, [float](3 * $s), [float](2 * $s)) }
    $lin.Dispose(); $pan.Dispose()
}
function Averi-Clic {
    $k = $script:skin
    if ($script:antojo -ge 40) {
        $script:antojo = 0; Sonido 'comer'
        for ($i = 0; $i -lt 4; $i++) { Nuevo-Corazon }
        Decir (Azar $k.Comer) 'abiertos'
    } else {
        Sonido 'yip'; Nuevo-Corazon
        Decir (Azar $k.Clic) (@('cerrados', 'abiertos')[$Rnd.Next(2)])
    }
    $form.Invalidate()
}

# ================= SEBASTIAN SOLACE: SU TIENDA =================
# Abrir programas da "investigación"; en la tienda se cambia por objetos reales de Pressure.
$script:modoTienda = $false; $script:investigacion = 10; $script:inventario = New-Object System.Collections.ArrayList
$script:visitas = 0; $script:comprasVisita = 0; $script:toques = 0; $script:iconosTienda = @{}
$script:enfadoFx = 0; $script:destello = 0
$visitasTimer = New-Object System.Windows.Forms.Timer
$visitasTimer.Interval = 90000
$visitasTimer.Add_Tick({ $visitasTimer.Stop(); $script:visitas = 0 })
function Icono-Tienda($it) {
    if (-not $it.Img) { return $null }
    if (-not $script:iconosTienda.ContainsKey($it.Id)) { $script:iconosTienda[$it.Id] = Cargar-Img $it.Img }
    return $script:iconosTienda[$it.Id]
}
function Dibujar-Objeto($g, $id, $x, $y, $s) {
    $it = @($script:skin.Tienda | Where-Object { $_.Id -eq $id })[0]
    $ic = if ($it) { Icono-Tienda $it } else { $null }
    if ($ic) { $g.DrawImage($ic, [float]$x, [float]$y, [float]$s, [float]$s); return }
    # Flash Beacon: no hay dibujo en la wiki, así que es un faro amarillo
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 220 80))), [float]($x + $s * 0.2), [float]($y + $s * 0.15), [float]($s * 0.6), [float]($s * 0.6))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 60 64 70))), [float]($x + $s * 0.3), [float]($y + $s * 0.62), [float]($s * 0.4), [float]($s * 0.3))
}
function Sebastian-Clic {
    if ($script:modoTienda) {
        # tocarle dentro de la tienda: se enfada cada vez más
        $k = $script:skin; $script:toques++
        Actor-Golpe 'S'
        if ($script:toques -ge 7) { Sebastian-Enfado 'Te lo advertí...'; $script:toques = 0 }
        else { Decir $k.Tocar[[Math]::Min($script:toques - 1, $k.Tocar.Count - 1)] }
        return
    }
    Tienda-Entrar
}
function Tienda-Entrar {
    $k = $script:skin
    $script:visitas++; $script:comprasVisita = 0; $script:toques = 0
    $visitasTimer.Stop(); $visitasTimer.Start()
    $script:modoTienda = $true; $script:modoSkins = $false
    if ($script:visitas -ge 4) { Sebastian-Enfado (Azar $k.Entrar3); $script:visitas = 2 }
    elseif ($script:visitas -ge 2) { Decir (Azar $k.Entrar2) }
    else { Decir (Azar $k.Entrar) }
    Mostrar-Pagina; $form.Invalidate()
}
function Tienda-Salir {
    $k = $script:skin; $script:modoTienda = $false
    if ($script:comprasVisita -eq 0) { Decir (Azar $k.SalirSinComprar) } else { Decir (Azar $k.Salir) }
    Mostrar-Pagina; $form.Invalidate()
}
function Tienda-Comprar($it) {
    $k = $script:skin
    if ($script:investigacion -lt $it.Precio) { Decir (Azar $k.Pobre); Actor-Golpe 'S'; return }
    $script:investigacion -= $it.Precio; $script:comprasVisita++
    [void]$script:inventario.Add($it.Id); while ($script:inventario.Count -gt 5) { $script:inventario.RemoveAt(0) }
    Sonido 'compra'
    Flotante "-$($it.Precio)" 150 262 (C 255 190 70) 22 'Bahnschrift'
    if ($it.Id -eq 'flash') {
        # le enciende el Flash Beacon en la cara
        Sonido 'flash'; $script:destello = 12; Actor-Golpe 'S'; Sacudir $form 8
        Decir (Azar @('¡¡GAAAAAAAH!!', '*GEURH* ...No. Lo. Vuelvas. A. Hacer.'))
    }
    elseif ($it.Id -eq 'pilas') { Decir (Azar $k.ComprarPilas) }
    elseif ($it.Escaso) { Decir (Azar $k.ComprarEscaso) }
    else { Decir (Azar $k.Comprar) }
    $form.Invalidate()
}
function Sebastian-Enfado($texto) {
    $script:enfadoFx = 26; Actor-Golpe 'S'; Sacudir $form 14
    Flotante 'GET. OUT!' 480 90 (C 255 40 40) 42 'Bahnschrift'
    Decir $texto
}

# ================= PURSUER: LA CAZA =================
$script:presas = 0; $script:estamina = 110.0; $script:acechando = $false
$script:zarpas = New-Object System.Collections.ArrayList; $script:ondas = New-Object System.Collections.ArrayList; $script:gotas = New-Object System.Collections.ArrayList
$script:rojoFx = 0
$acechoTimer = New-Object System.Windows.Forms.Timer
$acechoTimer.Interval = 5000
$acechoTimer.Add_Tick({ $acechoTimer.Stop(); if ($script:skin.Estilo -eq 'dod' -and $script:acechando) { Pursuer-Desacecho } })
function Pursuer-Zarpas($n) { for ($i = 0; $i -lt $n; $i++) { [void]$script:zarpas.Add(@{ X = [double]$Rnd.Next(430, 700); Y = [double]$Rnd.Next(80, 200); A = $Rnd.Next(-35, 35); T = 32 }) } }
function Pursuer-Sangre($n) { for ($i = 0; $i -lt $n; $i++) { [void]$script:gotas.Add(@{ X = [double]$Rnd.Next(450, 700); Y = [double]$Rnd.Next(90, 190); VX = ($Rnd.NextDouble() - 0.5) * 4; VY = -$Rnd.NextDouble() * 4; T = 30 }) } }
function Pursuer-Ataque($tipo, $texto) {
    if (Ocupado) { return }
    if ($script:acechando) { Pursuer-Desacecho; return }
    if ($script:estamina -lt 20 -and $tipo -ne 'presa') { Decir '*Jadea. Necesita recuperar el aliento.*'; return }
    $a = $script:actores['P']
    switch ($tipo) {
        'zarpazo' {
            $script:estamina -= 15; Sonido 'zarpazo'; Pursuer-Zarpas 1; if ($a) { $a.Dash = 10 }
            Decir $(if ($texto) { $texto } else { '*Zarpazo.* Sus garras cortan como cuchillas.' })
        }
        'espada' {
            $script:estamina -= 30; Sonido 'espada'; Sonido 'corte'; Pursuer-Zarpas 3; Pursuer-Sangre 10; $script:rojoFx = 8; if ($a) { $a.Dash = 14 }
            Decir $(if ($texto) { $texto } else { '*Desenvaina la espada negra.* ¡CORTE! *La herida sangra.*' })
        }
        'aullido' {
            $script:estamina -= 25; Sonido 'aullido'; Sonido 'onda'
            [void]$script:ondas.Add(@{ R = 10.0; T = 34 }); Sacudir $form 16
            Decir $(if ($texto) { $texto } else { '*AÚLLA.* Nada se atreve a responder a su llamada.' })
        }
        'presa' {
            $script:presas++; Sonido 'corte'; Pursuer-Zarpas 2; Pursuer-Sangre 6
            Flotante '+1 PRESA' 470 100 (C 255 52 41) 26 'Arial Black'
            Decir $texto
        }
    }
    $script:estamina = [Math]::Max(0, $script:estamina)
    $form.Invalidate()
}
function Pursuer-Acecho {
    if ($script:acechando -or (Ocupado)) { return }
    $script:acechando = $true
    $a = $script:actores['P']; if ($a) { $a.Alfa = 0.06 }
    Sonido 'acecho'; Decir '...te veo. *Desaparece entre los árboles.*'
    $acechoTimer.Stop(); $acechoTimer.Interval = $Rnd.Next(3500, 7000); $acechoTimer.Start()
    Invalidar-Escena
}
function Pursuer-Desacecho {
    $script:acechando = $false; $acechoTimer.Stop()
    $a = $script:actores['P']; if ($a) { $a.Alfa = 1.0; $a.Dash = 14 }
    Sonido 'zarpazo'; Sonido 'corte'; Pursuer-Zarpas 3; Pursuer-Sangre 12; $script:rojoFx = 10; Sacudir $form 10
    Flotante '¡CARNE FRESCA!' 440 90 (C 255 52 41) 32 'Arial Black'
    Decir '¡AHH, CARNE FRESCA!'
}
function Pursuer-Clic { Pursuer-Ataque (Azar @('zarpazo', 'zarpazo', 'espada', 'aullido')) }
# animación de efectos de Pursuer y Sebastian (la llama el temporizador del fondo)
function Efectos-Caza {
    $hay = $false
    for ($i = $script:zarpas.Count - 1; $i -ge 0; $i--) { $script:zarpas[$i].T--; $hay = $true; if ($script:zarpas[$i].T -le 0) { $script:zarpas.RemoveAt($i) } }
    for ($i = $script:ondas.Count - 1; $i -ge 0; $i--) { $o = $script:ondas[$i]; $o.T--; $o.R += 11; $hay = $true; if ($o.T -le 0) { $script:ondas.RemoveAt($i) } }
    for ($i = $script:gotas.Count - 1; $i -ge 0; $i--) { $o = $script:gotas[$i]; $o.T--; $o.X += $o.VX; $o.Y += $o.VY; $o.VY += 0.6; $hay = $true; if ($o.T -le 0) { $script:gotas.RemoveAt($i) } }
    if ($script:rojoFx -gt 0) { $script:rojoFx--; $hay = $true }
    if ($script:enfadoFx -gt 0) { $script:enfadoFx--; $hay = $true }
    if ($script:destello -gt 0) { $script:destello--; $hay = $true }
    if ($script:estamina -lt 110) { $script:estamina = [Math]::Min(110.0, $script:estamina + 0.3); $hay = $true }
    if ($script:acechando) { $hay = $true }
    if ($hay) { Invalidar-Escena; $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](268 * $script:K), [int](400 * $script:K), [int](40 * $script:K)))) }
}

# ================= KASANE TETO: PAJARITOS (BIRDBRAIN) =================
# Cada app que abres atrae a un pajarito. Al quinto, uno se le posa en la cabeza: ¡BIRDBRAIN!
$script:pajaros = New-Object System.Collections.ArrayList
$script:birdbrains = 0
# sitios donde se posan: encima de las fotos y en el suelo
$script:posaderos = @(@(462, 70), @(500, 70), @(492, 170), @(530, 172), @(448, 290), @(520, 290))
function Teto-Cabeza {
    $a = $script:actores['T']; $oy = if ($a) { $a.OY } else { 0 }
    $ox = if ($a) { $a.OX } else { 0 }
    return @((643 + $ox), (90 + $oy))
}
function Pajaros-Vivos { return @($script:pajaros | Where-Object { $_.Est -ne 'huye' }).Count }
function Teto-Pajaro {
    $n = Pajaros-Vivos
    if ($n -ge 5) { return }
    $lado = if ($Rnd.Next(2) -eq 0) { 1 } else { -1 }
    $sx = if ($lado -eq 1) { 400 } else { 760 }
    if ($n -eq 4) { $t = Teto-Cabeza; $cab = $true }
    else {
        $usados = @($script:pajaros | Where-Object { $_.Est -ne 'huye' } | ForEach-Object { $_.P })
        $libres = @(0..($script:posaderos.Count - 1) | Where-Object { $usados -notcontains $_ })
        $pi = $libres[$Rnd.Next($libres.Count)]; $t = $script:posaderos[$pi]; $cab = $false
    }
    [void]$script:pajaros.Add(@{ X = [double]$sx; Y = [double]$Rnd.Next(60, 120); TX = [double]$t[0]; TY = [double]$t[1]; Est = 'vuela'; Dir = $lado; F = $Rnd.NextDouble() * 6; P = $(if ($cab) { -1 } else { $pi }); Cab = $cab })
    Sonido 'pio'
}
function Teto-Birdbrain {
    $script:birdbrains++
    Sonido 'birdbrain'; $script:tetoVozT = [Environment]::TickCount
    Flotante 'BIRDBRAIN!' 444 110 (C 255 214 60) 34 'Arial Black'
    $a = $script:actores['T']; if ($a) { $a.Salto = 12 }
    Decir-Fijo (Azar @('¡Un pajarito en la cabeza! Ahora sí que tengo cerebro de pájaro. ¡BIRDBRAIN!', '¡Hiii~! ...¿por qué me miráis todos? ¿Tengo algo en el pelo?', '¡Cinco pajaritos! Uno se ha quedado a vivir aquí arriba. Se llama Pan.'))
    $form.Invalidate()
}
$script:tetoVozT = 0; $script:tetoClics = New-Object System.Collections.ArrayList; $script:tetoArrastre = 0
# elige el audio según lo que dice (la primera palabra clave que encuentre)
$TetoPalabras = @(
    ,@('buenos días|good morning', 'morning'), ,@('buenas noches|good night|a dormir', 'goodnight'), ,@('birdbrain|cerebro de pájaro', 'birdbrain')
    ,@('hiii|hi hi', 'hola'), ,@('baguette|\bpan\b', 'baguette'), ,@('♪|canta|tararea|la la', 'canta'), ,@('pajarit|pájaro|\bpío', 'tweet')
    ,@('bye|adiós|hasta luego|nos vemos', 'seeya'), ,@('oh,? no', 'ohno'), ,@('¡ay[!,]', 'ow'), ,@('perdón|lo siento', 'sorry'), ,@('\bups\b|\buy\b', 'oops2')
    ,@('espera', 'wait'), ,@('¿qué\?|¿eh\?', 'what'), ,@('\bhola\b|\bhey\b|\boye\b', 'hey'), ,@('vamos|let''s go', 'letsgo'), ,@('¡sí|\bsí[,!.]', 'yes')
    ,@('no, no|¡no!', 'nonono'), ,@('\bric[oa]\b|ñam', 'yummy'), ,@('\bmon[oa]\b|guap|adorable', 'cute'), ,@('\bwow\b|\bhala\b', 'wow')
    ,@('yupi|genial|ta-chán|yay', 'alegre'), ,@('feliz|content[oa]', 'happy'), ,@('\bteto\b', 'teto'), ,@('okay|\bvale\b', 'okay'), ,@('\?', 'huh')
)
function Voz-Teto($txt) {
    $ahora = [Environment]::TickCount
    if (($ahora - $script:tetoVozT) -lt 1500 -or ($ahora - $script:ultimoSonido) -lt 600) { return }
    $clave = $null
    foreach ($p in $TetoPalabras) { if ($txt -match $p[0]) { $clave = $p[1]; break } }
    if (-not $clave) { if ($Rnd.Next(2) -eq 0) { $clave = Azar @('hehe', 'hi', 'hey') } else { return } }
    $script:tetoVozT = $ahora
    Sonido-De 'Kasane Teto' $clave
}
function Teto-Clic {
    $a = $script:actores['T']; if ($a) { $a.Salto = 12 }
    $ahora = [Environment]::TickCount; [void]$script:tetoClics.Add($ahora)
    while ($script:tetoClics.Count -gt 0 -and ($ahora - $script:tetoClics[0]) -gt 2500) { $script:tetoClics.RemoveAt(0) }
    if ($script:tetoClics.Count -ge 4) {
        $script:tetoClics.Clear(); Sonido 'ow'; $script:tetoVozT = $ahora
        Flotante '@_@' 600 80 (C 214 40 64) 26 'Arial Black'
        Decir (Azar @('¡Ay! ¡Que me mareo de tanto saltar! *Da vueltas como una peonza.*', '¡Ay, ay! ¡Para! Veo pajaritos. ...ah, no, son los de siempre.'))
        $form.Invalidate(); return
    }
    foreach ($i in 0..2) { Flotante '♪' (580 + $i * 40) (90 + $Rnd.Next(30)) (@((C 214 40 64), (C 246 170 30), (C 255 255 255))[$i]) 22 'Segoe UI Symbol' }
    if ((Pajaros-Vivos) -gt 0) {
        # al saltar, los pájaros salen volando
        foreach ($b in $script:pajaros) { if ($b.Est -ne 'huye') { $b.Est = 'huye'; $b.Dir = $(if ($b.X -lt 600) { -1 } else { 1 }) } }
        Sonido 'pio'; Sonido 'byebye'
        Decir (Azar @('¡Bye-bye, pajaritos! ...¡ay, no, volved!', '¡Hiii! *Los pájaros salen volando.* Bueno, ya volverán. Siempre vuelven.', '*Salta de alegría y espanta a todos los pájaros.* ¡Ups!'))
    } else {
        $v = Azar $script:skin.Voces
        Sonido $v[1]; Decir $v[0]
    }
    $form.Invalidate()
}
function Teto-Tick {
    if ($script:pajaros.Count -eq 0) { return }
    for ($i = $script:pajaros.Count - 1; $i -ge 0; $i--) {
        $b = $script:pajaros[$i]; $b.F += 0.9
        switch ($b.Est) {
            'vuela' {
                if ($b.Cab) { $t = Teto-Cabeza; $b.TX = $t[0]; $b.TY = $t[1] }
                $dx = $b.TX - $b.X; $dy = $b.TY - $b.Y; $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
                if ($d -lt 8) { $b.X = $b.TX; $b.Y = $b.TY; if ($b.Cab) { $b.Est = 'cabeza'; Teto-Birdbrain } else { $b.Est = 'posado'; if ($Rnd.Next(3) -eq 0) { Sonido 'tweet'; $script:tetoVozT = [Environment]::TickCount } } }
                else { $v = [Math]::Min(9, $d); $b.X += $dx / $d * $v; $b.Y += $dy / $d * $v - [Math]::Sin($b.F) * 1.2; $b.Dir = $(if ($dx -ge 0) { 1 } else { -1 }) }
            }
            'cabeza' { $t = Teto-Cabeza; $b.X = $t[0]; $b.Y = $t[1] }
            'huye' { $b.X += $b.Dir * 12; $b.Y -= 3; if ($b.Y -lt 68 -or $b.X -lt 410 -or $b.X -gt 738) { $script:pajaros.RemoveAt($i) } }
        }
    }
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](290 * $script:K), [int](400 * $script:K), [int](46 * $script:K))))
}
# paloma dibujada: cuerpo gris, cuello brillante, pico naranja; aletea si vuela
function Dibujar-Pajaro($g, $x, $y, $esc, $vuela, $fase, $dir) {
    $st = $g.Save()
    $g.TranslateTransform([float]$x, [float]$y); $g.ScaleTransform([float]($esc * $dir), [float]$esc)
    $gris = New-Object System.Drawing.SolidBrush((C 150 160 178)); $oscuro = New-Object System.Drawing.SolidBrush((C 104 112 132))
    $g.FillPolygon($oscuro, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(-9, -5)), (New-Object System.Drawing.PointF(-17, -8)), (New-Object System.Drawing.PointF(-16, -1))))
    $g.FillEllipse($gris, -11, -10, 21, 12)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 110 176 160))), 4, -11, 7, 6)
    $g.FillEllipse($oscuro, 6, -17, 10, 9)
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 240 150 40))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(15, -14)), (New-Object System.Drawing.PointF(20, -12)), (New-Object System.Drawing.PointF(15, -11))))
    $g.FillEllipse([System.Drawing.Brushes]::Black, 11, -15, 2.6, 2.6)
    if ($vuela) {
        $al = [Math]::Sin($fase) * 11
        $g.FillPolygon($oscuro, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(-6, -7)), (New-Object System.Drawing.PointF(4, -7)), (New-Object System.Drawing.PointF(-4, [float](-8 - $al)))))
    } else {
        $g.FillEllipse($oscuro, -7, -8, 13, 7)
        $pata = New-Object System.Drawing.Pen((C 220 90 70), 1.6)
        $g.DrawLine($pata, -2, 1, -2, 6); $g.DrawLine($pata, 3, 1, 3, 6); $pata.Dispose()
    }
    $gris.Dispose(); $oscuro.Dispose()
    $g.Restore($st)
}
# foto del videoclip como polaroid pegada con celo
function Dibujar-Polaroid($g, $img, $x, $y, $w, $ang) {
    if (-not $img) { return }
    $st = $g.Save(); $g.TranslateTransform([float]($x + $w / 2), [float]($y + $w * 0.55)); $g.RotateTransform([float]$ang)
    $h = $w * 1.12
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 60 120 20 40))), [float](-$w / 2 + 4), [float](-$h / 2 + 5), [float]$w, [float]$h)
    $g.FillRectangle([System.Drawing.Brushes]::White, [float](-$w / 2), [float](-$h / 2), [float]$w, [float]$h)
    $m = $w * 0.07; $lado = $w - 2 * $m
    $g.DrawImage($img, [float](-$w / 2 + $m), [float](-$h / 2 + $m), [float]$lado, [float]$lado)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 250 226 120))), [float](-$w * 0.18), [float](-$h / 2 - 6), [float]($w * 0.36), 12)
    $g.Restore($st)
}

# ================= TOKEN (femtanyl): FICHAS Y BREAKCORE =================
# Cada app es una ficha en la recreativa. Muchos clics seguidos llenan el HYPE: al máximo, ¡BREAKCORE!
$script:tkFichas = 0; $script:tkHype = 0.0; $script:tkFx = 0; $script:tkPal = New-Object System.Collections.ArrayList
$TokenPalabras = @('CH4S3R', 'P3T', 'M3SS', 'S33K H3LP', 'KATAMARI', 'ACT RIGHT', 'DINNER!', 'LOTTERY', 'HEAD UP', 'GIRL HELL 1999', 'WAR GIRL', 'H3Y', 'REACTOR')
function Token-Palabra { [void]$script:tkPal.Add(@{ Txt = (Azar $TokenPalabras); X = [double]$Rnd.Next(416, 620); Y = [double]$Rnd.Next(70, 230); T = 24; Rot = $Rnd.Next(-14, 15) }) }
$script:tkCd = 1
$TokenCanciones = @('AND IM GONE', 'DINNER!', 'MAGFEST', 'WEIGHTLESS!', 'REACTOR', 'BODY THE PISTOL', 'MIX. 01 - PICKMEUP!', 'MIX. 02 - BOTHERED!')
function Token-Portada($n) {
    $script:tkCd = $n; $a = $script:actores['K']; if (-not $a) { return }
    $pose = if ($n -eq 1) { 'main' } else { "cd$n" }
    $a.Pose = $pose; $a.Base = $pose; $a.Hasta = 0; $a.Frame = 0; Seleccionar-Frame $a
}
function Token-Clic {
    $a = $script:actores['K']; if ($a) { $a.Temblor = 10 }
    Token-Portada (($script:tkCd % 8) + 1)
    $script:tkHype = [Math]::Min(100, $script:tkHype + 22)
    Sonido 'golpe'; Token-Palabra
    if ($script:tkHype -ge 100) { Token-Breakcore } else { Decir (Azar $script:skin.Clic) }
    $form.Invalidate()
}
function Token-Breakcore {
    $script:tkHype = 0; $script:tkFx = 60
    Sonido 'breakcore'; Sacudir $form 12
    for ($i = 0; $i -lt 4; $i++) { Token-Palabra }
    Decir-Fijo (Azar @('¡¡BREAKCORE MODE!! *Todo tiembla. Token está feliz.*', '¡DROP! *Las ventanas vibran a 200 BPM.*', '¡¡MÁS ALTO!! *Se le cae una oreja. Se la vuelve a poner sin dejar de bailar.*'))
}
function Token-Tick {
    $hay = $false
    if ($script:tkHype -gt 0) { $script:tkHype = [Math]::Max(0.0, $script:tkHype - 0.35); $hay = $true }
    if ($script:tkFx -gt 0) {
        $script:tkFx--; $hay = $true
        $a = $script:actores['K']; if ($a -and $script:tkFx % 5 -eq 0) { $a.Temblor = 5 }
        if ($script:tkFx % 9 -eq 0) { Token-Palabra }
        if ($script:tkFx % 3 -eq 0) { Token-Portada ($Rnd.Next(1, 9)) }
        if ($script:tkFx % 12 -eq 0) { Sacudir $form 4 }
    }
    for ($i = $script:tkPal.Count - 1; $i -ge 0; $i--) { $w = $script:tkPal[$i]; $w.T--; $w.Y -= 1.2; $hay = $true; if ($w.T -le 0) { $script:tkPal.RemoveAt($i) } }
    if ($hay) { $form.Invalidate() }
}

# ================= TETRA (YonKaGor): MENSAJES Y NO MOLESTAR =================
# Cada app trae un mensaje de "neems". Cada cuatro clics, Tetra se pone (o se quita) el No molestar.
$script:popMsgs = 0; $script:popDND = $false; $script:popNoti = $null; $script:popClics = 0; $script:popFx = 0
$script:popIni = [Environment]::TickCount; $script:peces = New-Object System.Collections.ArrayList
function Tetra-Mensaje {
    $script:popMsgs++
    if ($script:popDND) { return $false }
    $script:popNoti = @{ T = 80; Txt = (Azar @('hey', '¿sigues ahí?', 'mira esto jaja', '¿una partida?', '¿te acuerdas de 2020?', 'buenas noches :)', '¿has visto mi historia?', 'jajaja', 'te echo de menos', '¿llamada luego?')) }
    Sonido 'ping'; return $true
}
function Tetra-Clic {
    $a = $script:actores['E']; if ($a) { $a.Salto = 12 }
    $script:popClics++; $script:popFx = 8
    if ($script:popClics % 4 -eq 0) {
        $script:popDND = -not $script:popDND; Sonido 'vhs'
        if ($script:popDND) { Decir 'No molestar: ACTIVADO. *Se pone los cascos.* No es nada personal.' }
        else { Decir 'No molestar: desactivado. Ya me pueden escribir. ...igual tardo en contestar.' }
    } elseif ($Rnd.Next(3) -eq 0) {
        Sonido 'disco'
        Decir (Azar @('*Se pone a bailar disco en el sitio.* Esto sonaba mucho en 2020.', '*Baila un poco. Se le mueven los pendientes de pez.*', '*Tararea muy bajito.* ...you''re just like pop music...'))
    } else { Decir (Azar $script:skin.Clic) }
    $form.Invalidate()
}
function Tetra-Tick {
    if ($script:peces.Count -eq 0) {
        for ($i = 0; $i -lt 7; $i++) { [void]$script:peces.Add(@{ X = [double]$Rnd.Next(410, 760); Y = [double]$Rnd.Next(80, 250); V = 0.6 + $Rnd.NextDouble() * 1.2; E = 0.7 + $Rnd.NextDouble() * 0.6; F = $Rnd.NextDouble() * 6 }) }
    }
    foreach ($p in $script:peces) { $p.X += $p.V; $p.F += 0.25; if ($p.X -gt 780) { $p.X = 400; $p.Y = [double]$Rnd.Next(80, 250) } }
    if ($script:popNoti) { $script:popNoti.T--; if ($script:popNoti.T -le 0) { $script:popNoti = $null } }
    if ($script:popFx -gt 0) { $script:popFx-- }
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](276 * $script:K), [int](410 * $script:K), [int](44 * $script:K))))
}
# pececito neón (tetra neón): cuerpo plateado, franja azul brillante y cola roja
function Dibujar-Tetra-Pez($g, $x, $y, $esc, $fase) {
    $st = $g.Save(); $g.TranslateTransform([float]$x, [float]$y); $g.ScaleTransform([float]$esc, [float]$esc)
    $cola = [Math]::Sin($fase) * 2
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 200 240 60 70))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(-9, 0)), (New-Object System.Drawing.PointF(-16, [float](-4 + $cola))), (New-Object System.Drawing.PointF(-16, [float](4 + $cola)))))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 210 220 230 240))), -11, -4, 22, 8)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 230 255 70 90))), -10, 0, 9, 3)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 255 60 230 255))), -8, -2, 17, 2)
    $g.FillEllipse([System.Drawing.Brushes]::Black, 6, -2, 2.5, 2.5)
    $g.Restore($st)
}
# copia de una imagen pintada de un solo color (para el efecto de colores separados de VHS / glitch)
function Imagen-Color($img, $col, $alto) {
    if (-not $img) { return $null }
    $ancho = [Math]::Max(1, [int]($img.Width * $alto / $img.Height))
    $b = New-Object System.Drawing.Bitmap($ancho, [int]$alto)
    $g = [System.Drawing.Graphics]::FromImage($b); $g.InterpolationMode = 'HighQualityBicubic'
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = 0; $cm.Matrix11 = 0; $cm.Matrix22 = 0; $cm.Matrix40 = $col.R / 255.0; $cm.Matrix41 = $col.G / 255.0; $cm.Matrix42 = $col.B / 255.0
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $ancho, [int]$alto)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.Dispose(); $ia.Dispose(); return $b
}
# imagen con los colores separados (rojo/cian) como en una tele vieja
function Dibujar-RGB($g, $img, $c1, $c2, $x, $y, $w, $h, $sep) {
    if ($c1) { $g.DrawImage($c1, [float]($x - $sep), [float]$y, [float]$w, [float]$h) }
    if ($c2) { $g.DrawImage($c2, [float]($x + $sep), [float]$y, [float]$w, [float]$h) }
    if ($img) { $g.DrawImage($img, [float]$x, [float]$y, [float]$w, [float]$h) }
}
# ================= KEVIN (Don't Touch My Pizza): SU PIZZA =================
# Cada app que abres es un trozo que se come. Si tocas la pizza, se enfada: cuchillo y pistola,
# luego "I'm going to bite you" y a la tercera, motosierra y fuego. A veces aparece queso azul:
# ese sí lo puedes quitar (haz clic en la pizza) y te lo agradece.
$script:pzTrozos = 8; $script:pzComidas = 0; $script:pzEnfado = 0.0; $script:pzQueso = $false; $script:pzFx = 0
$script:pzReparto = 0; $script:pzGrito = $null; $script:pzLluvia = New-Object System.Collections.ArrayList
$PizzaX = 452; $PizzaY = 224; $PizzaR = 30
$script:pzRect = @(498, 90, 248, 172); $script:pzLienzo = @(414, 90, 334, 172)
function Dibujar-Trozo($g, $x, $y, $s, $ang) {
    # un trozo de pizza: triángulo de queso con borde de masa y pepperoni
    $st = $g.Save(); $g.TranslateTransform([float]$x, [float]$y); $g.RotateTransform([float]$ang); $g.ScaleTransform([float]($s / 20.0), [float]($s / 20.0))
    $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 12)), (New-Object System.Drawing.PointF(-10, -9)), (New-Object System.Drawing.PointF(10, -9)))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 255 206 84))), $pts)
    $g.DrawPolygon((New-Object System.Drawing.Pen((C 120 60 20), 1.2)), $pts)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 210 140 60))), -11, -12, 22, 5)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 120 60 20), 1.2)), -11, -12, 22, 5)
    foreach ($q in @(@(-4, -3), @(3, -2), @(0, 4))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 210 40 40))), [float]($q[0] - 2.2), [float]($q[1] - 2.2), 4.4, 4.4) }
    $g.Restore($st)
}
function Dibujar-Pizza($g, $cx, $cy, $r, $trozos, $queso) {
    # plato
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 60 0 0 0))), [float]($cx - $r - 6), [float]($cy - $r * 0.25 + $r), [float](2 * $r + 12), [float]($r * 0.5))
    $g.FillEllipse([System.Drawing.Brushes]::White, [float]($cx - $r - 7), [float]($cy - $r - 7), [float](2 * $r + 14), [float](2 * $r + 14))
    $g.DrawEllipse((New-Object System.Drawing.Pen((C 30 30 30), 2)), [float]($cx - $r - 7), [float]($cy - $r - 7), [float](2 * $r + 14), [float](2 * $r + 14))
    $g.DrawEllipse((New-Object System.Drawing.Pen((C 180 190 200), 1)), [float]($cx - $r - 3), [float]($cy - $r - 3), [float](2 * $r + 6), [float](2 * $r + 6))
    if ($trozos -le 0) { return }
    $masa = New-Object System.Drawing.SolidBrush((C 214 146 64)); $queso1 = New-Object System.Drawing.SolidBrush((C 255 206 84))
    $tinta = New-Object System.Drawing.Pen((C 30 30 30), 1.6)
    for ($i = 0; $i -lt $trozos; $i++) {
        $a0 = -90 + $i * 45
        $g.FillPie($masa, [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r), [float]$a0, 45)
        $g.FillPie($queso1, [float]($cx - $r + 5), [float]($cy - $r + 5), [float](2 * $r - 10), [float](2 * $r - 10), [float]$a0, 45)
        $g.DrawPie($tinta, [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r), [float]$a0, 45)
        # pepperoni
        foreach ($q in @(@(0.55, 14), @(0.75, 32))) {
            $an = ($a0 + $q[1]) * [Math]::PI / 180; $px = $cx + [Math]::Cos($an) * $r * $q[0]; $py = $cy + [Math]::Sin($an) * $r * $q[0]
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 206 40 40))), [float]($px - 3.5), [float]($py - 3.5), 7, 7)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 255 140 120))), [float]($px - 2), [float]($py - 2.5), 3, 2)
        }
    }
    $masa.Dispose(); $queso1.Dispose(); $tinta.Dispose()
    if ($queso) {
        # queso azul encima y olor que sube
        $azul = New-Object System.Drawing.SolidBrush((C 120 160 210)); $vena = New-Object System.Drawing.SolidBrush((C 50 80 150))
        foreach ($q in @(@(-12, -6), @(8, -12), @(4, 8), @(-6, 12), @(14, 4))) {
            $g.FillEllipse($azul, [float]($cx + $q[0] - 6), [float]($cy + $q[1] - 5), 12, 10)
            $g.FillEllipse($vena, [float]($cx + $q[0] - 2), [float]($cy + $q[1] - 2), 3, 3)
        }
        $azul.Dispose(); $vena.Dispose()
        $olor = New-Object System.Drawing.Pen((ARGB 200 110 190 60), 2.5)
        for ($i = 0; $i -lt 3; $i++) {
            $ox = $cx - 14 + $i * 14; $f = $script:fase * 2 + $i
            $g.DrawBezier($olor, [float]$ox, [float]($cy - $r - 6), [float]($ox + 8 * [Math]::Sin($f)), [float]($cy - $r - 16), [float]($ox - 8 * [Math]::Sin($f)), [float]($cy - $r - 26), [float]$ox, [float]($cy - $r - 36))
        }
        $olor.Dispose()
    }
}
function Pizza-En-Raton {
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    return ([Math]::Pow($x - $PizzaX, 2) + [Math]::Pow($y - $PizzaY, 2) -le [Math]::Pow($PizzaR + 8, 2))
}
# poses que ocupan todo el lienzo de Paint (fuego y unicornio)
function Kevin-Grande($pose, $ms) {
    $a = $script:actores['V']; if (-not $a) { return }
    $a.Rect = $script:pzLienzo; $a.Llenar = $true
    Actor-Pose 'V' $pose $ms
}
function Kevin-Comer($linea) {
    if ($script:pzTrozos -le 0) { Decir "$linea (Kevin mira el plato vacío. La pizza nueva está en camino.)"; return }
    $script:pzTrozos--; Sonido 'nam'
    Flotante 'ÑAM' ($PizzaX - 22) ($PizzaY - 50) (C 70 200 40) 22 'Comic Sans MS'
    if ($script:pzTrozos -le 0) {
        $script:pzComidas++; $script:pzReparto = 50
        Actor-Pose 'V' 'feliz' 1500
        Decir "$linea ...¡Y se acabó la pizza! *Llama al repartidor.*"
    } else {
        if ($Rnd.Next(3) -eq 0) { Actor-Pose 'V' 'chulo' 1400 }
        Decir $linea
    }
    $form.Invalidate()
}
function Pizza-Tocar {
    if (Ocupado) { return }
    $k = $script:skin
    if ($script:pzQueso) {
        # quitar el queso azul es lo único que se le puede hacer a su pizza
        $script:pzQueso = $false; $a = $script:actores['V']; if ($a) { $a.Base = 'main' }
        Sonido 'pop'; Actor-Pose 'V' 'feliz' 1800
        Flotante '¡GRACIAS!' ($PizzaX - 40) ($PizzaY - 52) (C 255 110 200) 18 'Comic Sans MS'
        Decir (Azar @('¡Gracias! ¡Fuera queso azul! Huele fatal, de verdad. Puedes... no, no puedes tocar la pizza. Pero gracias.', '*Respira hondo.* ¡Aire limpio! Eres de los buenos. Pero la pizza sigue sin tocarse.', '¡Me has salvado! El queso azul es mi enemigo mortal. Bueno, el segundo. El primero es el que toca mi pizza.'))
        $form.Invalidate(); return
    }
    $script:pzEnfado = [Math]::Min(100, $script:pzEnfado + 38)
    # el grito grande (en el segundo aviso no: ese GIF ya lleva su propio texto)
    $script:pzGrito = if ($script:pzEnfado -ge 60 -and $script:pzEnfado -lt 100) { $null } else { @{ Txt = "DON'T TOUCH MY PIZZA!"; T = 30 } }
    if ($script:pzEnfado -ge 100) {
        # tercer aviso: motosierra y fuego
        $script:pzFx = 80; Sonido 'grito'; Sacudir $form 16
        Actor-Pose 'V' 'motosierra' 1700
        Decir-Fijo (Azar $k.Rabia)
    } elseif ($script:pzEnfado -ge 60) {
        Sonido 'grr'; Sacudir $form 6; Actor-Pose 'V' 'muerde' 2600; Actor-Golpe 'V'
        Decir (Azar $k.Toque2)
    } else {
        Sonido 'grr'; Actor-Pose 'V' 'arma' 2400
        Decir (Azar $k.Toque1)
    }
    $form.Invalidate()
}
function Kevin-Clic {
    $k = $script:skin; $r = $Rnd.Next(100)
    if ($r -lt 4) {
        Sonido 'baile'; Kevin-Grande 'unicornio' 6000
        Decir '*Se sube a un unicornio y cabalga por el arcoíris.* ¡ADIÓS, MUNDO! ...vuelvo en seis segundos.'
    } elseif ($r -lt 34) {
        Sonido 'baile'; Actor-Pose 'V' 'baile' 4300
        foreach ($i in 0..3) { Flotante (Azar @('♪', '♫')) (520 + $i * 50) (96 + $Rnd.Next(40)) (@((C 70 200 40), (C 30 100 240), (C 255 110 200), (C 70 200 40))[$i]) 22 'Segoe UI Symbol' }
        Decir (Azar @('*Baila como en 2010.* ¡Mira qué pasos!', '*Baila.* ¡Esto es lo que hago cuando nadie toca mi pizza!', '*Baila sin ritmo pero con muchas ganas.*'))
    } elseif ($r -lt 52) {
        Actor-Pose 'V' 'micro' 5000
        foreach ($i in 0..2) { Flotante '♪' (540 + $i * 60) (100 + $Rnd.Next(30)) (C 255 110 200) 22 'Segoe UI Symbol' }
        Decir (Azar @('*Coge un micro.* ¡Esta va por todos los que NO tocan mi pizza!', '*Canta con chaqueta y todo.* Don''t touch my pizza~ ♪', '¡Un, dos, un, dos! *Golpea el micro.* ¿Se oye? ¡NO TOQUÉIS MI PIZZA!'))
    } elseif ($r -lt 66) {
        Actor-Pose 'V' 'feliz' 1500; Decir (Azar @('¡YAAAY!', '¡Hola! ¡Hola! ¡HOLA!', '*Levanta los brazos.* ¡SOY FELIZ! Tengo pizza.'))
    } elseif ($r -lt 76) {
        Actor-Pose 'V' 'piensa' 2600; Decir (Azar @('*Piensa.* ¿Y si la pizza fuera de mermelada? ...no. Eso es un crimen.', '*Piensa muy fuerte.* ...se me ha olvidado lo que pensaba. Algo de pizza.', 'Hmm. ¿Tú tienes cara de tocar pizzas ajenas? *Te mira entrecerrando los ojos.*'))
    } else {
        Actor-Pose 'V' 'chulo' 1600; Decir (Azar $k.Clic)
    }
    $form.Invalidate()
}
function Kevin-Queso {
    if ($script:pzQueso -or $script:pzTrozos -le 0) { return $false }
    $script:pzQueso = $true; Sonido 'grr'
    $a = $script:actores['V']; if ($a) { $a.Base = 'sudor'; Actor-Pose 'V' 'grita' 1600 }
    Decir (Azar @('¡¿QUIÉN HA PUESTO QUESO AZUL EN MI PIZZA?! ¡Huele fatal! (haz clic en la pizza para quitarlo)', '*Huele.* ...¡PUAJ! ¡QUESO AZUL! Quítalo, quítalo, quítalo. (clic en la pizza)', 'No me gusta el queso azul porque huele muy mal. ¡Y ahora está EN MI PIZZA! (clic en la pizza para quitarlo)')) 'serio'
    $form.Invalidate(); return $true
}
function Kevin-Tick {
    $hay = $false
    $a = $script:actores['V']
    # vuelve a su sitio después del fuego o del unicornio
    if ($a -and $a.Llenar -and $a.Pose -notin @('fuego', 'unicornio')) { $a.Rect = $script:pzRect; $a.Llenar = $false; $hay = $true }
    if ($script:pzEnfado -gt 0 -and $script:pzFx -le 0) { $script:pzEnfado = [Math]::Max(0.0, $script:pzEnfado - 0.3); $hay = $true }
    if ($script:pzFx -gt 0) {
        $script:pzFx--; $hay = $true
        if ($script:pzFx -eq 52) { Kevin-Grande 'fuego' 2600; Sonido 'grr' }
        if ($script:pzFx % 10 -eq 0) { Sacudir $form 5 }
        if ($script:pzFx % 3 -eq 0) { [void]$script:pzLluvia.Add(@{ X = [double]$Rnd.Next(420, 740); Y = 70.0; V = 2.5 + $Rnd.NextDouble() * 3; A = $Rnd.Next(0, 360); Fuego = $true }) }
        if ($script:pzFx -eq 0) { $script:pzEnfado = 45 }
    }
    if ($script:pzReparto -gt 0) {
        $script:pzReparto--
        if ($script:pzReparto -eq 0) {
            $script:pzTrozos = 8; Sonido 'ding'; Actor-Pose 'V' 'feliz' 1600
            for ($i = 0; $i -lt 8; $i++) { [void]$script:pzLluvia.Add(@{ X = [double]$Rnd.Next(420, 740); Y = 60.0 - $Rnd.Next(0, 40); V = 2 + $Rnd.NextDouble() * 2; A = $Rnd.Next(0, 360); Fuego = $false }) }
            if (-not $script:discutiendo) { Decir (Azar @('*Ding dong.* ¡¡PIZZA NUEVA!! *La abraza.* Hola, preciosa.', '*Ding dong.* ¡Ha llegado el repartidor! Ocho trozos. Todos míos.', '*Ding dong.* ¡PIZZA! ...que nadie se acerque. Ni tú.')) 'abiertos' }
        }
        $hay = $true
    }
    for ($i = $script:pzLluvia.Count - 1; $i -ge 0; $i--) { $t = $script:pzLluvia[$i]; $t.Y += $t.V; $t.A += 7; $hay = $true; if ($t.Y -gt 270) { $script:pzLluvia.RemoveAt($i) } }
    if ($script:pzGrito) { $script:pzGrito.T--; $hay = $true; if ($script:pzGrito.T -le 0) { $script:pzGrito = $null } }
    if ($script:pzQueso) { $hay = $true }
    if ($hay) { $form.Invalidate() }
}
# elige el fotograma de un GIF según el tiempo (para las intros)
function Gif-Frame($img, $info, $ms) {
    if (-not $img -or $info.N -le 1) { return }
    $tot = 0; foreach ($d in $info.Del) { $tot += $d }
    $t = $ms % $tot; $i = 0
    while ($i -lt $info.N - 1 -and $t -ge $info.Del[$i]) { $t -= $info.Del[$i]; $i++ }
    [void]$img.SelectActiveFrame((New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])), $i)
}

# ================= GRAN: ANTIHUMAN INC. =================
# Su canción ("Are You Sure He's a Pharmacist?") suena de fondo mientras la skin está puesta (si el sonido está activado).
# Cada app que abres es un sujeto de prueba que recibe una dosis de Fury Mix: unas veces sale un furry nuevo y otras falla.
# Haz clic en Gran y se tapa la cara, como en el vídeo. Como invitado en las discusiones sale siempre con la cara tapada.
$script:gr = $null; $script:grMusica = $null
function Gran-Reset { if (-not $script:gr) { $script:gr = @{ Sujetos = 0; Exitos = 0; Tapa = 0; Fx = 0; FxCol = (C 32 208 44) } } }
function Gran-Volumen { return [Math]::Max(0.0, [Math]::Min(1.0, 0.7 * $script:aj.Volumen / 100.0)) }
function Gran-Musica-On($desdeCero) {
    if (-not $script:aj.Sonido) { return }
    if ($script:grMusica -and -not $desdeCero) { return }
    Gran-Musica-Off
    try {
        $mp = New-Object System.Windows.Media.MediaPlayer
        $mp.Open([Uri](Ruta 'skins\gran\cancion.mp3')); $mp.Volume = (Gran-Volumen); $mp.Play()
        $script:grMusica = $mp
    } catch { $script:grMusica = $null }
}
function Gran-Musica-Off {
    if ($script:grMusica) { try { $script:grMusica.Stop(); $script:grMusica.Close() } catch {}; $script:grMusica = $null }
}
# se tapa la cara (con la transición del vídeo) durante unos milisegundos
function Gran-Tapar($ms) {
    $a = $script:actores['G']; if (-not $a -or -not $script:gr) { return }
    if ($a.Base -ne 'tapada') { $a.Base = 'tapada'; Actor-Pose 'G' 'tapar' 360 }
    $script:gr.Tapa = [Environment]::TickCount + $ms
}
function Gran-Clic {
    Gran-Tapar 5000
    Decir (Azar $script:skin.Clic)
}
# una app abierta = un sujeto de prueba
function Gran-Dosis($linea) {
    $e = $script:gr; if (-not $e) { Decir $linea; return }
    $e.Sujetos++
    if ($Rnd.Next(100) -lt 62) {
        $e.Exitos++; $e.Fx = 10; $e.FxCol = (C 32 208 44)
        Flotante '+1 FURRY' 160 262 (C 32 208 44) 20 'Bahnschrift'
    } else {
        $e.Fx = 10; $e.FxCol = (C 200 30 60)
        Flotante 'FALLIDO' 160 262 (C 230 50 70) 20 'Bahnschrift'
    }
    if ($e.Sujetos % 10 -eq 0) {
        $pc = [int](100 * $e.Exitos / $e.Sujetos)
        Gran-Tapar 6000
        Decir-Fijo "Informe para el consejo: $($e.Sujetos) sujetos, $pc % de éxito. $(if ($pc -ge 60) { 'Aceptable. La especie superior avanza.' } else { 'Insuficiente. Subiré la dosis.' })" 'abiertos'
    } else { Decir $linea }
    $form.Invalidate()
}
function Gran-Tick {
    $e = $script:gr; if (-not $e) { return }
    # la canción: se repite al acabar, sigue el volumen y se calla si quitas el sonido
    if (-not $script:aj.Sonido) { Gran-Musica-Off }
    elseif (-not $script:grMusica) { Gran-Musica-On $false }
    else {
        try {
            $mp = $script:grMusica
            if ([Math]::Abs($mp.Volume - (Gran-Volumen)) -gt 0.01) { $mp.Volume = (Gran-Volumen) }
            if ($mp.NaturalDuration.HasTimeSpan -and $mp.Position -ge ($mp.NaturalDuration.TimeSpan - [TimeSpan]::FromMilliseconds(120))) { $mp.Position = [TimeSpan]::Zero; $mp.Play() }
        } catch {}
    }
    # vuelve a destaparse
    if ($e.Tapa -gt 0 -and [Environment]::TickCount -ge $e.Tapa) {
        $e.Tapa = 0; $a = $script:actores['G']
        if ($a) { $a.Base = 'main'; Actor-Pose 'G' 'main' 0 }
        $e.Fx = 6; $e.FxCol = (C 32 208 44)
    }
    if ($e.Fx -gt 0) { $e.Fx--; Invalidar-Escena }
}

# ================= KENNYOUNG: SU CANAL DE YOUTUBE =================
# Cada app que abres son visitas y likes. Cada 8 apps, concierto con la banda.
# Haz clic en él y toca un acorde: el amplificador sube; si llega al máximo, la guitarra EXPLOTA.
# El botón SUSCRIBIRSE del reproductor funciona (con campanita).
$script:kyVistas = 0; $script:kyLikes = 0; $script:kyApps = 0; $script:kyAmp = 0.0; $script:kyRotas = 0
$script:kyCancion = 0; $script:kyProg = 0.0; $script:kySub = $false; $script:kyFx = 0; $script:kyConc = 0; $script:kyFlash = 0
$KyBoton = @(184, 14, 100, 24)   # botón SUSCRIBIRSE (en la barra de arriba)
function Ky-Duracion { return (150 + (($script:kyCancion * 37) % 70)) }   # segundos de cada canción (entre 2:30 y 3:40)
function Ky-Tiempo($s) { return ('{0}:{1:00}' -f [int][Math]::Floor($s / 60), [int]($s % 60)) }
function Ky-Numero($n) { if ($n -ge 1000000) { return ('{0:0.0} M' -f ($n / 1000000.0)) } elseif ($n -ge 1000) { return ('{0:0.0} K' -f ($n / 1000.0)) } else { return "$n" } }
function Sub-En-Raton {
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    return ($x -ge $KyBoton[0] -and $x -le $KyBoton[0] + $KyBoton[2] -and $y -ge $KyBoton[1] -and $y -le $KyBoton[1] + $KyBoton[3])
}
# panel con el borde verde en zigzag de sus pegatinas
function Dibujar-Pegatina($g, $x, $y, $w, $h, $relleno) {
    $pts = New-Object System.Collections.ArrayList; $paso = 13; $sal = 7
    for ($i = 0; $i -le [int]($w / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x + $i * $paso), [float]($y - $o)))) }
    for ($i = 0; $i -le [int]($h / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x + $w + $o), [float]($y + $i * $paso)))) }
    for ($i = 0; $i -le [int]($w / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x + $w - $i * $paso), [float]($y + $h + $o)))) }
    for ($i = 0; $i -le [int]($h / $paso); $i++) { $o = if ($i % 2 -eq 0) { $sal } else { 2 }; [void]$pts.Add((New-Object System.Drawing.PointF([float]($x - $o), [float]($y + $h - $i * $paso)))) }
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 120 110 235 140))), [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 3), ($_.Y + 3)) }))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 110 235 140))), [System.Drawing.PointF[]]$pts.ToArray())
    $r = Ruta-Redonda $x $y $w $h 10
    $g.FillPath((New-Object System.Drawing.SolidBrush($relleno)), $r); $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), 2)), $r); $r.Dispose()
}
# los cuadros marrones de su camisa
function Dibujar-Cuadros($g, $x, $y, $w, $h) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 96 74 68))), $x, $y, $w, $h)
    $cl = New-Object System.Drawing.SolidBrush((ARGB 90 190 168 160)); $os = New-Object System.Drawing.Pen((ARGB 70 40 28 24), 2)
    for ($cy = $y + 4; $cy -lt $y + $h; $cy += 14) { for ($cx = $x + 4 + (($cy / 14) % 2) * 7; $cx -lt $x + $w; $cx += 14) { $g.FillRectangle($cl, [float]$cx, [float]$cy, 7, 7) } }
    for ($cx = $x; $cx -lt $x + $w; $cx += 28) { $g.DrawLine($os, [float]$cx, [float]$y, [float]$cx, [float]($y + $h)) }
    $cl.Dispose(); $os.Dispose()
}
# vídeos del minirreproductor: se cargan la primera vez que hacen falta
$script:kyVids = @{}
function Ky-Gif($n) {
    if (-not $script:kyVids.ContainsKey($n)) {
        $d = $script:skin.Videos[$n]; if (-not $d) { return $null }
        $img = Cargar-Img $d[0]; $script:kyVids[$n] = if ($img) { @{ Img = $img; Info = (Gif-Info $img); Titulo = $d[1] } } else { $null }
    }
    return $script:kyVids[$n]
}
# pone un vídeo suyo en el minirreproductor durante un rato
function Ky-Video($n, $ms) { $script:kyVideo = @{ N = $n; Hasta = [Environment]::TickCount + $ms } }
function Ky-Inv { $Z = $script:K; $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](244 * $Z), $form.ClientSize.Width, [int](80 * $Z)))) }
function Ky-Suscribir {
    if (Ocupado) { return }
    $script:kySub = -not $script:kySub
    if ($script:kySub) {
        Sonido 'campana'; $script:kyLikes += 1
        Flotante '¡SUSCRITO!' 560 200 (C 255 255 255) 16 'Arial Black'
        Ky-Video 'yap' 2500
        Decir (Azar @('¡Gracias por suscribirte! ¿Le has dado a la campanita? ...sí, se la has dado. Ha sonado.', '*Te mira muy serio.* Gracias. De verdad. Ahora somos 1 más. Annyeong.', '¡Un suscriptor más! Esto lo celebro con un acorde. *Rasguea.*'))
    } else {
        Decir (Azar @('¿Te has desuscrito? ...vale. Lo entiendo. *Toca un acorde muy triste.*', '*Se queda mirando el contador.* No pasa nada. No pasa nada. ...ha pasado algo.')); Ky-Video 'triste' 3000
    }
    $form.Invalidate()
}
function Ky-App($linea) {
    $script:kyApps++; $v = $Rnd.Next(120, 999); $script:kyVistas += $v; $script:kyLikes += $Rnd.Next(5, 60)
    Flotante "+$v visitas" 600 200 (C 255 255 255) 13 'Arial Black'
    if ($script:kyApps % 8 -eq 0) {
        $script:kyConc = 140; Sonido 'publico'; Sonido 'riff'
        Ky-Video 'concierto' 8000
        Decir-Fijo (Azar $script:skin.Concierto)
    } else { Sonido 'acorde'; Decir $linea }
    $form.Invalidate()
}
function Ky-Clic {
    $k = $script:skin
    $script:kyAmp = [Math]::Min(100, $script:kyAmp + 22)
    Sonido 'acorde'
    foreach ($i in 0..1) { Flotante (Azar @('♪', '♫', '★')) (470 + $Rnd.Next(0, 220)) (90 + $Rnd.Next(0, 80)) (@((C 255 255 255), (C 255 80 160), (C 255 255 255))[$Rnd.Next(3)]) 22 'Segoe UI Symbol' }
    if ($script:kyAmp -ge 100) {
        # la guitarra explota
        $script:kyAmp = 0; $script:kyRotas++; $script:kyFx = 50; $script:kyFlash = 8
        Sonido 'kaboom'; Sacudir $form 14
        Ky-Video 'kaboom' 3500
        Decir-Fijo (Azar $k.Kaboom)
    } elseif ($script:kyAmp -ge 70) {
        Ky-Video 'diablo' 2600
        Decir (Azar @('¡MÁS ALTO! *El amplificador empieza a echar humo.*', '¡ESTO ES PUNK! *Los ojos le dan vueltas.* ...para ya, que explota.', '*El ampli pita.* Eso es buena señal. Creo.'))
    } else {
        Decir (Azar $k.Clic)
    }
    $form.Invalidate()
}
function Ky-Tick {
    $k = $script:skin
    if ($script:kyAmp -gt 0) { $script:kyAmp = [Math]::Max(0.0, $script:kyAmp - 0.4) }
    if ($script:kyFx -gt 0) { $script:kyFx--; if ($script:kyFx % 8 -eq 0) { Sacudir $form 3 } }
    if ($script:kyFlash -gt 0) { $script:kyFlash-- }
    if ($script:kyConc -gt 0) { $script:kyConc--; if ($script:kyConc % 25 -eq 0) { $script:kyVistas += $Rnd.Next(50, 300) } }
    # la canción avanza; al acabar, pasa a la siguiente
    $script:kyProg += 0.05 / (Ky-Duracion) * 6
    if ($script:kyProg -ge 1) {
        $script:kyProg = 0; $script:kyCancion = ($script:kyCancion + 1) % $k.Canciones.Count
        if (-not $script:discutiendo -and -not (Ocupado) -and $Rnd.Next(3) -eq 0) { Decir "Siguiente canción: $($k.Canciones[$script:kyCancion]). Esta me gusta. Bueno, me gustan todas. Son mías." 'abiertos' }
    }
    if ($script:kyFx -gt 0 -or $script:kyConc -gt 0 -or $script:kyFlash -gt 0) { $form.Invalidate() }
    else { Ky-Inv; $Z = $script:K; $form.Invalidate((New-Object System.Drawing.Rectangle([int](396 * $Z), [int](56 * $Z), [int](168 * $Z), [int](140 * $Z)))) }   # el minirreproductor siempre se mueve
}

# ================= ENFOSI: DEFIENDE LA ESTATUA =================
# Llegan Glaggles a la estatua. Algunos son Enphosians disfrazados con un fallo (piel de otro color,
# símbolo falso, sin símbolo o sin cara). Clic en el falso para descubrirlo y acabar con él.
# Clic en un inocente = strike. Con tres strikes viene el Ojo de Enphoso. Datos de las wikis del juego.
$script:ef = $null; $script:efImgs = @{}
function Enfosi-HPMax($ola) { if ($ola -ge 7) { return 10000 } elseif ($ola -ge 4) { return 7500 } else { return 5000 } }
function Enfosi-Reset {
    $script:ef = @{ Ola = 1; EnOla = 0; PorOla = 4; Strikes = 0; Puntos = 0; Bintar = 0; HP = 5000; HPMax = 5000; Errores = 0
        Ojo = 0; Sobber = $false; W = $null; Cola = 0; Auto = 0; Banner = $null; Cartel = $null; Siguiente = $null; Rojo = 0; Negro = 0; NX = 0; NY = 0 }
    $a = $script:actores['W']; if ($a) { $a.Visible = $false }
}
function Enfosi-Img($n) {
    if (-not $script:efImgs.ContainsKey($n)) { $script:efImgs[$n] = Cargar-Img "skins\enfosi\$n" }
    return $script:efImgs[$n]
}
function Enfosi-Pose($pose) {
    $a = $script:actores['W']; if (-not $a -or -not $a.Imgs[$pose]) { return }
    $a.Pose = $pose; $a.Base = $pose; $a.Hasta = 0; $a.Frame = 0; $a.Acc = 0; Seleccionar-Frame $a
}
function Enfosi-Cartel($img, $ticks, $siguiente) { $script:ef.Cartel = @{ Img = $img; T = $ticks; Max = $ticks }; $script:ef.Siguiente = $siguiente }
# un Glaggle nuevo empieza a caminar hacia la estatua
function Enfosi-Llega {
    $e = $script:ef; if (-not $e -or $e.W -or $e.Banner -or $e.Cartel) { return }
    $a = $script:actores['W']; if (-not $a) { return }
    $e.Auto = 0
    # el primero de cada oleada es siempre el Glaggle nuevo de esa oleada
    $tipo = if ($e.EnOla -eq 0) { $EnfosiTipos[$e.Ola - 1] } else { $EnfosiTipos[$Rnd.Next(0, $e.Ola)] }
    $falso = if ($Rnd.NextDouble() -lt 0.45) { $Rnd.Next(1, 5) } else { 0 }
    $e.W = @{ Tipo = $tipo; Falso = $falso; Estado = 'anda'; X = 700.0; Vida = $EnfosiVida[$tipo]; Atq = 0; Jefe = $false; Baile = 0 }
    $e.EnOla++
    Enfosi-Pose $(if ($falso) { "$tipo$falso" } else { $tipo })
    $a.Rect = @(700, 148, 74, 120); $a.Visible = $true; $a.Alfa = 1.0; $a.Baila = $false; $a.OY = 0
    Decir $EnfosiTexto[$tipo]
    Invalidar-Escena
}
function Enfosi-Jefe {
    $e = $script:ef; $a = $script:actores['W']; if (-not $a) { return }
    $j = $EnfosiJefes[$e.Ola]
    $e.W = @{ Tipo = $j[0]; Falso = 0; Estado = 'revelado'; X = 680.0; Vida = $j[2]; Atq = 0; Jefe = $true; Baile = 0 }
    Enfosi-Pose $j[0]
    $a.Rect = @(680, 118, 100, 150); $a.Visible = $true; $a.Alfa = 1.0; $a.Baila = $false
    Sonido 'alarma'; Sacudir $form 8
    Decir-Fijo $j[3]
}
function Enfosi-Clic($id) {
    $e = $script:ef; if (-not $e) { return }
    if ($id -eq 'E') {
        if (-not $e.W -and -not $e.Banner -and -not $e.Cartel) { Enfosi-Llega } else { Decir (Azar $script:skin.Clic) }
        return
    }
    $w = $e.W; if (-not $w) { return }
    $a = $script:actores['W']
    switch ($w.Estado) {
        'anda' {
            Sonido 'golpe'; if ($a) { $a.Temblor = 6 }
            if ($w.Falso -eq 0) { Enfosi-Strike } else { Enfosi-Revela 'golpe' }
        }
        { $_ -in @('revelado', 'ataca') } {
            $w.Vida--; Sonido 'golpe'; if ($a) { $a.Flash = 6; $a.Temblor = 6 }
            if ($w.Vida -le 0) { Enfosi-Muere }
        }
        'baila' { Decir '¡Déjalo! Está celebrando que ha llegado a la estatua.' }
    }
    $form.Invalidate()
}
function Enfosi-Strike {
    $e = $script:ef; $w = $e.W
    $e.Strikes++; $e.Errores++; $e.Puntos -= 100; $e.Rojo = 10
    Sonido 'buzzer'; Sacudir $form 8
    Flotante 'STRIKE' 470 120 (C 230 30 30) 30 'Arial Black'
    $w.Estado = 'muere'
    if ($e.Strikes -ge 3 -and $e.Ojo -eq 0 -and -not $e.Sobber) {
        $e.Ojo = 1; Sonido 'ojo'
        Decir-Fijo '¡Tres strikes! El Ojo de Enphoso viene a por ti. No se le puede hacer daño...'
    } else {
        Decir-Fijo "¡STRIKE! Era un $($EnfosiNombre[$w.Tipo]) inocente. *Suena un zumbido de error enorme.* (strike $($e.Strikes) de 3)"
    }
}
function Enfosi-Revela($como) {
    $e = $script:ef; $w = $e.W; $a = $script:actores['W']
    $w.Estado = if ($como -eq 'estatua') { 'ataca' } else { 'revelado' }
    Enfosi-Pose "$($w.Tipo)_e"
    Sonido 'revela'; Sacudir $form 6
    $e.Negro = 14; $e.NX = $w.X + 37; $e.NY = 200
    Flotante '¡ENPHOSIAN!' ($w.X - 40) 110 (C 20 20 20) 22 'Arial Black'
    if ($como -eq 'golpe') { Decir-Fijo "¡Era un Enphosian! El $($EnfosiNombre[$w.Tipo]) $($EnfosiFallo[$w.Falso]). ¡Acaba con él!" 1500 }
    else { Decir-Fijo "¡Un Enphosian ha llegado a la estatua! El $($EnfosiNombre[$w.Tipo]) $($EnfosiFallo[$w.Falso]). ¡Clic en él, rápido!" 1500 }
}
function Enfosi-Muere {
    $e = $script:ef; $w = $e.W
    $p = if ($w.Jefe) { 1000 } else { 200 }
    $e.Puntos += $p; Sonido 'ding'
    Flotante "+$p" ($w.X) 120 (C 255 214 60) 24 'Arial Black'
    $w.Estado = 'muere'
    if ($w.Jefe) { Decir-Fijo "¡Has derrotado a $($EnfosiNombre[$w.Tipo])! +1000 puntos." }
    else { Decir (Azar @('¡Enphosian eliminado! +200.', '¡Uno menos! La estatua está a salvo... de momento.', '¡Bien visto! Ese no era un Glaggle de verdad.')) }
}
function Enfosi-Fin-Glaggle {
    $e = $script:ef; $w = $e.W; $e.W = $null
    $a = $script:actores['W']; if ($a) { $a.Visible = $false; $a.Baila = $false }
    if ($w -and $w.Jefe) { Enfosi-Nueva-Ola; return }
    if ($e.EnOla -ge $e.PorOla) { Enfosi-Fin-Ola }
}
function Enfosi-Fin-Ola {
    $e = $script:ef
    $n = $e.Errores + $(if ($e.Sobber) { 3 } else { 0 })
    $r = @('glaggle', 'awesome', 'basic', 'coulddobetter', 'doingbad', 'enphosed')[[Math]::Min(5, $n)]
    $nom = @{ glaggle = 'GLAGGLE'; awesome = 'AWESOME'; basic = 'BASIC'; coulddobetter = 'COULD DO BETTER'; doingbad = 'DOING BAD'; enphosed = 'ENPHOSED' }[$r]
    $e.Bintar += 2; Sonido 'moneda'
    $sig = if ($e.Ola -in @(2, 4, 6)) { 'jefe' } else { 'ola' }
    Enfosi-Cartel "rango_$r.png" 60 $sig
    Decir-Fijo "¡Fin de la oleada $($e.Ola)! Rango: $nom. +2 Bintar."
}
function Enfosi-Nueva-Ola {
    $e = $script:ef
    if ($e.Ola -ge 7) {
        Decir-Fijo "¡Has sobrevivido a las 7 oleadas! Puntos: $($e.Puntos). La estatua sigue en pie. Volvemos a empezar."
        $b = $e.Bintar; Enfosi-Reset; $script:ef.Bintar = $b
    } else { $e.Ola++ }
    $e = $script:ef
    $e.EnOla = 0; $e.Strikes = 0; $e.Errores = 0; $e.Ojo = 0; $e.Sobber = $false
    $max = Enfosi-HPMax $e.Ola; if ($max -gt $e.HPMax) { $e.HPMax = $max; $e.HP = $max }
    $t = $EnfosiTipos[$e.Ola - 1]
    $e.Banner = @{ Img = "$($t)_oleada.png"; T = 55 }
    Sonido 'ola'
    if ($e.Ola -gt 1) { Decir-Fijo "Oleada $($e.Ola) de 7: ¡llegan los $($EnfosiNombre[$t])s!" 1000 }
}
function Enfosi-Derrota {
    $e = $script:ef
    Sonido 'revela'; Sacudir $form 14
    Enfosi-Cartel 'gameover.jpg' 70 'reset'
    Decir-Fijo "La estatua ha caído. ENPHOSED. Has llegado a la oleada $($e.Ola) con $($e.Puntos) puntos."
}
function Enfosi-Tick {
    $e = $script:ef; if (-not $e) { return }
    $a = $script:actores['W']; $est = $script:actores['E']
    if ($e.Rojo -gt 0) { $e.Rojo-- }
    if ($e.Negro -gt 0) { $e.Negro-- }
    if ($e.Banner) { $e.Banner.T--; if ($e.Banner.T -le 0) { $e.Banner = $null } }
    if ($e.Cartel) {
        $e.Cartel.T--
        if ($e.Cartel.T -le 0) {
            $e.Cartel = $null; $s = $e.Siguiente; $e.Siguiente = $null
            switch ($s) { 'jefe' { Enfosi-Jefe } 'ola' { Enfosi-Nueva-Ola } 'reset' { $b = $e.Bintar; Enfosi-Reset; $script:ef.Bintar = $b; $script:ef.Banner = @{ Img = 'giggler_oleada.png'; T = 55 }; Sonido 'ola' } }
        }
    }
    $e = $script:ef
    # el Ojo de Enphoso se acerca; si llega, te convierte en Sobber
    if ($e.Ojo -gt 0) {
        $e.Ojo++
        if ($e.Ojo -ge 170) {
            $e.Ojo = 0; $e.Sobber = $true; $e.Rojo = 14; Sonido 'revela'; Sacudir $form 12
            Enfosi-Cartel 'gameover.jpg' 30 $null
            Decir-Fijo 'El Ojo de Enphoso te ha atrapado. Ahora eres un Sobber hasta que acabe la oleada.'
        }
    }
    # un Glaggle de vez en cuando aunque no abras nada (cada 25 s)
    if (-not $e.W -and -not $e.Banner -and -not $e.Cartel) {
        if ($e.Cola -gt 0) { $e.Cola--; Enfosi-Llega } else { $e.Auto++; if ($e.Auto -ge 500) { Enfosi-Llega } }
    }
    $w = $e.W
    if ($w -and $a) {
        $vel = if ($w.Jefe) { 0.9 } else { $EnfosiVel[$w.Tipo] }
        switch ($w.Estado) {
            'anda' {
                $w.X -= $vel
                if ($w.X -le 528) {
                    $w.X = 528
                    if ($w.Falso -gt 0) { Enfosi-Revela 'estatua' }
                    else { $w.Estado = 'baila'; $w.Baile = 34; $a.Baila = $true; Decir (Azar @('*El Glaggle llega a la estatua y baila. ¡Yeah!*', '¡Un inocente ha llegado sano y salvo! *Baila de alegría.*', '*Baila delante de la estatua... y explota en confeti.* ¡Era de los buenos!')) }
                }
            }
            'revelado' {
                $w.X -= $vel * $(if ($w.Tipo -eq 'cheerer') { 2.2 } else { 1.5 })
                if ($w.X -le 528) { $w.X = 528; $w.Estado = 'ataca' }
            }
            'ataca' {
                $w.Atq++
                if ($w.Atq % 20 -eq 1) {
                    $d = if ($w.Jefe) { 300 } else { $EnfosiDanio[$w.Tipo] }
                    $e.HP -= $d; $e.Errores = [Math]::Max($e.Errores, 1); Sonido 'estatua'
                    if ($est) { $est.Temblor = 8; $est.Flash = 4 }
                    Flotante "-$d" 440 110 (C 230 30 30) 22 'Arial Black'
                    # el Cheerer falso explota contra la estatua (y desaparece)
                    if ($w.Tipo -eq 'cheerer' -and -not $w.Jefe) { $e.Negro = 16; $e.NX = 520; $e.NY = 200; Sacudir $form 12; $w.Estado = 'muere'; $a.Alfa = 0.2 }
                    if ($e.HP -le 0) { $e.HP = 0; $e.W = $null; $a.Visible = $false; Enfosi-Derrota; return }
                }
            }
            'baila' {
                $w.Baile--
                if ($w.Baile -le 0) {
                    Sonido 'confeti'; $e.Puntos += 50
                    foreach ($i in 0..4) { Flotante (Azar @('✦', '★', '●')) ($w.X + $Rnd.Next(-10, 60)) (140 + $Rnd.Next(0, 60)) (@((C 255 214 60), (C 255 90 160), (C 90 200 255), (C 120 230 90), (C 255 255 255))[$i]) 18 'Segoe UI Symbol' }
                    Enfosi-Fin-Glaggle; Invalidar-Escena; return
                }
            }
            'muere' {
                $a.Alfa = [Math]::Max(0.0, $a.Alfa - 0.1)
                if ($a.Alfa -le 0) { Enfosi-Fin-Glaggle; Invalidar-Escena; return }
            }
        }
        $a.Rect = @([int]$w.X, $a.Rect[1], $a.Rect[2], $a.Rect[3])
    }
    Invalidar-Escena
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](276 * $script:K), [int](410 * $script:K), [int](44 * $script:K))))
}
# carita de las vidas (como la barra de strikes del juego)
function Dibujar-Carita($g, $x, $y, $r, $bien) {
    if ($bien) {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 214 60))), [float]($x - $r), [float]($y - $r), [float](2 * $r), [float](2 * $r))
        $p = New-Object System.Drawing.Pen((C 30 30 30), 1.6); $g.DrawEllipse($p, [float]($x - $r), [float]($y - $r), [float](2 * $r), [float](2 * $r))
        $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($x - $r * 0.4), [float]($y - $r * 0.45), [float]($r * 0.22), [float]($r * 0.42))
        $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($x + $r * 0.18), [float]($y - $r * 0.45), [float]($r * 0.22), [float]($r * 0.42))
        $g.DrawArc($p, [float]($x - $r * 0.6), [float]($y - $r * 0.55), [float]($r * 1.2), [float]($r * 1.1), 20, 140); $p.Dispose()
    } else {
        $p = New-Object System.Drawing.Pen((C 230 30 30), 3.5); $p.StartCap = 'Round'; $p.EndCap = 'Round'
        $g.DrawLine($p, [float]($x - $r * 0.8), [float]($y - $r * 0.8), [float]($x + $r * 0.8), [float]($y + $r * 0.8)); $g.DrawLine($p, [float]($x + $r * 0.8), [float]($y - $r * 0.8), [float]($x - $r * 0.8), [float]($y + $r * 0.8)); $p.Dispose()
    }
}

# ================= NANACHI (Made in Abyss): ESTOFADO DEL ABISMO Y MULLIDO =================
# Cada app echa un ingrediente a la olla; con 5, sirve un estofado del Abismo (cada vez le sale un poco mejor).
# Clic en Nanachi: le acaricias. El medidor MULLIDO sube; si le tocas mucho seguido, se incomoda y se aparta.
# Su "dibujo" de la pared enseña su cara del anime según lo que pase. Por el fondo suben los hilos del campo de fuerza.
$script:nn = $null
function Nn-Reset { if (-not $script:nn) { $script:nn = @{ Ing = 0; Estofados = 0; Mullido = 0.0; Toques = 0.0; Cara = $null; CaraHasta = 0; Fx = 0; Vapor = 0 } } }
$script:nnCaras = @{}
function Nn-Gif($n) {
    if (-not $script:nnCaras.ContainsKey($n)) {
        $r = $script:skin.Caritas[$n]; $img = if ($r) { Cargar-Img $r } else { $null }
        $script:nnCaras[$n] = if ($img) { @{ Img = $img; Info = (Gif-Info $img) } } else { $null }
    }
    return $script:nnCaras[$n]
}
function Nn-Liberar { foreach ($c in @($script:nnCaras.Values)) { if ($c) { $c.Img.Dispose() } }; $script:nnCaras = @{} }
# pone una cara en su dibujo de la pared durante un rato
function Nn-Cara($n, $ms) { Nn-Reset; $script:nn.Cara = $n; $script:nn.CaraHasta = [Environment]::TickCount + $ms }
function Nn-App($linea) {
    Nn-Reset; $e = $script:nn; $k = $script:skin
    $ing = $k.Ingredientes[$e.Ing % $k.Ingredientes.Count]; $e.Ing++
    Sonido 'plof'; $e.Vapor = 30
    Flotante '+1' 470 190 (C 236 170 190) 18 'Georgia'
    if ($e.Ing -ge $k.Ingredientes.Count) {
        # olla llena: se sirve el estofado (y cada vez le sale un poco menos horrible)
        $e.Ing = 0; $e.Estofados++; Sonido 'sorbo'; Nn-Cara 'mastica' 3500
        $n = $e.Estofados
        $txt = if ($n -le 2) { Azar @('Estofado del Abismo. Sabe fatal. Me da igual. Cómetelo.', '*Te pone un cuenco de algo marrón delante sin mirarte.* Nutritivo. Asqueroso. Ambas cosas.', 'Listo. Textura de barro. Si no te gusta, no lo comas. A mí me da lo mismo.') }
               elseif ($n -le 5) { Azar @('Estofado número ' + $n + '. Esta vez he quitado las espinas. Algunas.', '*Lo prueba primero.* ...mejor que el anterior. Que no es decir mucho. Nnaa.', 'Riko me enseñó a no hervirlo de golpe. Ahora solo sabe un poco a pescado.') }
               else { Azar @('Estofado número ' + $n + '. Está... bueno. ¿Está bueno? *Lo vuelve a probar.* Nnaa~ ¡Está bueno!', 'He aprendido a cocinar de verdad. Para cuando vuelva a ver a alguien especial. Toma, pruébalo tú primero.', 'Mira cómo brilla el caldo. Esto ya no es estofado del Abismo. Es estofado de Nanachi.') }
        Decir-Fijo $txt 'abiertos'
    } else {
        Nn-Cara $(if ($Rnd.Next(2) -eq 0) { 'chulo' } else { 'sentado' }) 3000
        Decir "$linea (A la olla, $ing. Por echar algo.)"
    }
    $form.Invalidate()
}
function Nn-Clic {
    Nn-Reset; $e = $script:nn; $k = $script:skin
    $e.Toques += 1.0; $e.Mullido = [Math]::Min(100.0, $e.Mullido + 9.0)
    Sonido 'brillo'
    foreach ($i in 0..1) { Flotante (Azar @('✿', '♥', '✦')) (610 + $Rnd.Next(0, 110)) (90 + $Rnd.Next(0, 90)) (@((C 236 170 190), (C 252 240 214), (C 190 230 170))[$Rnd.Next(3)]) 20 'Segoe UI Symbol' }
    if ($e.Mullido -ge 100.0) {
        $e.Mullido = 40.0; $e.Toques = 0.0; $e.Fx = 40; Nn-Cara 'feliz' 6000
        Decir-Fijo (Azar $k.MullidoMax) 'abiertos'
    } elseif ($e.Toques -ge 4.0) {
        $e.Toques = 2.0; Nn-Cara 'tapa' 3000
        $a = $script:actores['N']; if ($a) { $a.Dash = 14 }
        Decir (Azar $k.Mimos3)
    } elseif ($e.Toques -ge 2.0) {
        Nn-Cara 'verguenza' 2500; Decir (Azar $k.Mimos2)
    } else {
        Nn-Cara $(if ($Rnd.Next(2) -eq 0) { 'mimos' } else { 'ronroneo' }) 3000; Decir (Azar $k.Mimos1)
    }
    $form.Invalidate()
}
function Nn-Mitty {
    Nn-Reset; $k = $script:skin
    Sonido 'brillo'; Nn-Cara 'feliz' 3500
    $a = $script:actores['M']; if ($a) { $a.Salto = 10 }
    foreach ($i in 0..2) { Flotante '♥' (530 + $Rnd.Next(0, 80)) (178 + $Rnd.Next(0, 20)) (C 236 170 190) 18 'Segoe UI Symbol' }
    Decir (Azar $k.Mitty) 'abiertos'
    $form.Invalidate()
}
function Nn-Tick {
    Nn-Reset; $e = $script:nn
    # los toques se olvidan solos (unos 2,5 s cada uno) y el medidor baja muy despacio
    if ($e.Toques -gt 0.0) { $e.Toques = [Math]::Max(0.0, $e.Toques - 0.02) }
    if ($e.Mullido -gt 0.0) { $e.Mullido = [Math]::Max(0.0, $e.Mullido - 0.03) }
    if ($e.Fx -gt 0) { $e.Fx-- }
    if ($e.Vapor -gt 0) { $e.Vapor-- }
    # el dibujo de la pared, los hilos del campo de fuerza y el vapor siempre se mueven
    $Z = $script:K
    $form.Invalidate((New-Object System.Drawing.Rectangle([int](406 * $Z), [int](56 * $Z), [int](354 * $Z), [int](222 * $Z))))
    $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](270 * $Z), [int](410 * $Z), [int](50 * $Z))))
}
# silbato de explorador (los rangos del Abismo): rojo, azul, luna, negro y blanco
function Dibujar-Silbato($g, $x, $y, $col) {
    $g.FillPath((New-Object System.Drawing.SolidBrush($col)), (Ruta-Redonda $x $y 8 18 4))
    $g.DrawPath((New-Object System.Drawing.Pen((C 40 30 24), 1.2)), (Ruta-Redonda $x $y 8 18 4))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 40 30 24))), [float]($x + 2), [float]($y + 3), 4, 4)
    $g.DrawLine((New-Object System.Drawing.Pen((C 120 96 70), 1)), [float]($x + 4), [float]$y, [float]($x + 4), [float]($y - 8))
}
# el muñeco de pájaro que Nanachi cosió para Mitty (tela verde y rosa)
function Dibujar-Muneco($g, $x, $y) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), [float]($x - 2), [float]($y + 26), 40, 8)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 96 150 96))), [float]$x, [float]$y, 36, 30)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 236 170 190))), [float]($x + 8), [float]($y + 12), 20, 16)
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 230 200 120))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 32), [float]($y + 10))), (New-Object System.Drawing.PointF([float]($x + 44), [float]($y + 13))), (New-Object System.Drawing.PointF([float]($x + 32), [float]($y + 16)))))
    $g.FillEllipse([System.Drawing.Brushes]::White, [float]($x + 24), [float]($y + 6), 6, 6); $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($x + 26), [float]($y + 8), 3, 3)
    $pc = New-Object System.Drawing.Pen((C 60 44 34), 1); $pc.DashStyle = 'Dash'; $g.DrawEllipse($pc, [float]$x, [float]$y, 36, 30); $pc.Dispose()
}
# los hilos del campo de fuerza que solo ve Nanachi: líneas suaves que suben despacio
function Dibujar-Campo($g, $x0, $y0, $w, $h, $alfa) {
    $t = [Environment]::TickCount / 1000.0
    for ($i = 0; $i -lt 7; $i++) {
        $bx = $x0 + 20 + $i * ($w - 40) / 6.0
        $pts = New-Object System.Collections.ArrayList
        for ($yy = 0; $yy -le $h; $yy += 12) { [void]$pts.Add((New-Object System.Drawing.PointF([float]($bx + [Math]::Sin(($yy + $t * 40 + $i * 37) / 34.0) * 9), [float]($y0 + $h - $yy)))) }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alfa, 210, 255, 220), 1.4)
        $g.DrawCurve($pen, [System.Drawing.PointF[]]$pts.ToArray()); $pen.Dispose()
        # chispitas que suben por cada hilo
        $py = $y0 + $h - (($t * 22 + $i * 41) % $h)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $alfa * 3), 230, 255, 235))), [float]($bx + [Math]::Sin(($h - $py + $y0 + $t * 40 + $i * 37) / 34.0) * 9 - 2), [float]($py - 2), 4, 4)
    }
}

# ================= ANIMACIÓN DE FONDO (planta rodadora, agua de Dune) =================
$script:fase = 0.0; $script:tumbX = -300; $script:salto = 0
$ambTimer = New-Object System.Windows.Forms.Timer
$ambTimer.Interval = 50
# MODO SEGURO (epilepsia): apaga todos los destellos, flashes y parpadeos de color de las skins.
# Si añades un efecto nuevo que parpadee o haga flash, pon aquí su variable a 0.
function Sin-Destellos {
    if (-not $script:aj.Epilepsia) { return }
    $script:fogonazo = 0; $script:kyFlash = 0; $script:destello = 0; $script:rojoFx = 0; $script:flash = 0
    $script:enfadoFx = 0; $script:popFx = 0; $script:tkFx = 0; $script:pzFx = 0; $script:invFx = 0; $script:invEst = 0
    if ($script:gr) { $script:gr.Fx = 0 }
    if ($script:nn) { $script:nn.Fx = 0 }
    if ($script:es) { $script:es.Fx = 0 }
    foreach ($a in @($script:actores.Values)) { $a.Flash = 0; $a.Temblor = 0 }
}
$ambTimer.Add_Tick({
    Sin-Destellos
    $k = $script:skin; $Z = $script:K
    if ((Ocupado) -or -not $k) { return }
    $script:fase += 0.14
    if ($k.Estilo -eq 'oeste') {
        # planta rodadora cruzando la escena, buitres, polvo, agujeros de bala que se borran, fogonazo y duelo
        $script:tumbX += 5
        if ($script:tumbX -gt 800) { $script:tumbX = 380 - $Rnd.Next(0, 700) }
        $hay = $true
        if ($script:duelo) { Zodiac-Duelo-Tick }
        for ($i = $script:agujeros2.Count - 1; $i -ge 0; $i--) { $script:agujeros2[$i].T--; if ($script:agujeros2[$i].T -le 0) { $script:agujeros2.RemoveAt($i); $hay = $true } }
        if ($script:fogonazo -gt 0) { $script:fogonazo--; $hay = $true }
        if ($hay) { Invalidar-Escena; $form.Invalidate((New-Object System.Drawing.Rectangle([int](400 * $Z), [int](200 * $Z), [int](($form.ClientSize.Width / $Z - 400) * $Z), [int](60 * $Z)))) }
    }
    if ($k.Agua -and $script:pb) {
        # Dune flota en el agua; da un saltito cuando come
        $extra = 0; if ($script:salto -gt 0) { $script:salto--; $extra = - [Math]::Sin($script:salto / 10.0 * [Math]::PI) * 12 }
        $script:pb.Top = [int](($k.Pb[1] + [Math]::Sin($script:fase) * 3 + $extra) * $Z)
        $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](296 * $Z), $form.ClientSize.Width, [int](20 * $Z))))
    }
    if ($k.Estilo -eq 'culto' -and $script:ritualFx -gt 0) {
        $script:ritualFx--
        if ($script:ritualFx -eq 30) { Sonido 'tentaculos' }
        $form.Invalidate()
    }
    if ($k.Estilo -eq 'kaiju') { Kaiju-Particulas }
    if ($k.Estilo -in @('dod', 'pressure')) { Efectos-Caza }
    if ($k.Estilo -eq 'teto') { Teto-Tick }
    if ($k.Estilo -eq 'enfosi') { Enfosi-Tick }
    if ($k.Estilo -eq 'femta') { Token-Tick }
    if ($k.Estilo -eq 'pop') { Tetra-Tick }
    if ($k.Estilo -eq 'pizza') { Kevin-Tick }
    if ($k.Estilo -eq 'punk') { Ky-Tick }
    if ($k.Estilo -eq 'gran') { Gran-Tick }
    if ($k.Estilo -eq 'abismo') { Nn-Tick }
    if ($k.Estilo -eq 'evil') { Es-Tick }
    if ($k.Estilo -eq 'niebla') { Sf-Tick }
})

# ================= EVIL SCARY (Die of Death): LA RONDA ESPECIAL =================
# Como en el juego: se acerca a saltitos ("rebotes"); cada 6 rebotes suena la alarma STALL, STALL y después
# hace una carga de 8 saltos rápidos. Si llega hasta ti (distancia 0) te da un susto y vuelve al horizonte.
# Clic en él: PUNCH (lo aleja un poco). Clic durante la alarma o la carga: BLOCK (logro "Lucid Nightmare").
# Cada app que abres hace ruido y le hace botar hacia ti.
# Tiempos en milisegundos (cámbialos aquí para que sea más o menos agresivo):
$EsTiempos = @{ Rebote = 6000; Aviso = 2600; CargaIni = 430; CargaMin = 170; Susto = 1600 }
$script:es = $null
function Es-Reset {
    if (-not $script:es) {
        # a veces sale gigante (como en el juego): bota menos veces pero más lejos
        $gig = ($Rnd.Next(10) -eq 0)
        $script:es = @{ Dist = 100.0; Vis = 100.0; Rebotes = 0; Fase = 'lento'; Prox = [Environment]::TickCount + $EsTiempos.Rebote
            Cuenta = 0; Paso = $EsTiempos.CargaIni; Sustos = 0; Bloqueos = 0; Fx = 0; Hop = 0; Gigante = $gig }
    }
}
function Es-Sonido-Rebote {
    $d = $script:es.Dist
    Sonido $(if ($d -gt 60) { 'lejos' } elseif ($d -gt 30) { 'medio' } else { 'cerca' })
}
function Es-Rebote($n) {
    Es-Reset; $e = $script:es
    if ($e.Gigante) { $n = $n * 1.6 }
    $e.Dist = [Math]::Max(0.0, $e.Dist - $n); $e.Hop = 8
    Es-Sonido-Rebote
    if ($e.Dist -le 0.0) { Es-Susto }
}
function Es-Susto {
    $e = $script:es; $k = $script:skin
    $e.Sustos++; $e.Fx = [int]($EsTiempos.Susto / 50); $e.Fase = 'lento'; $e.Rebotes = 0
    $e.Prox = [Environment]::TickCount + $EsTiempos.Rebote + $EsTiempos.Susto
    Sonido 'grito'; Sacudir $form 14
    Decir-Fijo (Azar $k.Atrapado)
    $e.Dist = 100.0
}
function Es-App($linea) { Es-Reset; Es-Rebote 4.0; Decir $linea }
function Es-Clic {
    Es-Reset; $e = $script:es; $k = $script:skin
    if ($e.Fase -in @('aviso', 'carga')) {
        # BLOCK: justo cuando va a cargar o está cargando
        $e.Bloqueos++; $e.Dist = 100.0; $e.Fase = 'lento'; $e.Rebotes = 0; $e.Prox = [Environment]::TickCount + $EsTiempos.Rebote
        Sonido 'violin'
        Flotante 'LUCID NIGHTMARE' 450 120 (C 255 220 90) 20 'Arial Black'
        Decir-Fijo (Azar $k.Bloqueo)
    } else {
        # PUNCH: lo aleja un poco (no le hace daño: nadie puede)
        $e.Dist = [Math]::Min(100.0, $e.Dist + 12.0); $e.Hop = 6
        Flotante 'PUNCH!' (560 + $Rnd.Next(-40, 40)) 130 (C 255 255 255) 18 'Arial Black'
        Decir (Azar $k.Clic)
    }
    $form.Invalidate()
}
function Es-Tick {
    Es-Reset; $e = $script:es; $k = $script:skin; $ahora = [Environment]::TickCount
    if ($e.Fx -gt 0) { $e.Fx-- }
    if ($e.Hop -gt 0) { $e.Hop-- }
    if (-not (Ocupado) -and $ahora -ge $e.Prox) {
        switch ($e.Fase) {
            'lento' {
                $e.Rebotes++; $sustosAntes = $e.Sustos; Es-Rebote 5.0
                # si este rebote le ha hecho llegar hasta ti, ya se ha reiniciado: no toca alarma
                if ($e.Sustos -eq $sustosAntes) {
                    if ($e.Rebotes % $(if ($e.Gigante) { 4 } else { 6 }) -eq 0) {
                        # la alarma del Airbus: se queda quieto y avisa
                        $e.Fase = 'aviso'; $e.Prox = $ahora + $EsTiempos.Aviso; Sonido 'stall'; Decir-Fijo (Azar $k.Stall)
                    } else { $e.Prox = $ahora + $EsTiempos.Rebote }
                }
            }
            'aviso' { $e.Fase = 'carga'; $e.Cuenta = $(if ($e.Gigante) { 4 } else { 8 }); $e.Paso = $EsTiempos.CargaIni; $e.Prox = $ahora; Sonido 'violin' }
            'carga' {
                Es-Rebote 7.0
                if ($e.Fase -eq 'carga') {
                    $e.Cuenta--; $e.Paso = [Math]::Max($EsTiempos.CargaMin, $e.Paso - 35)
                    if ($e.Cuenta -le 0) { $e.Fase = 'lento'; $e.Prox = $ahora + $EsTiempos.Rebote } else { $e.Prox = $ahora + $e.Paso }
                }
            }
        }
    }
    # se mueve suave hasta su distancia y crece al acercarse (del horizonte hasta tus narices)
    $e.Vis += ($e.Dist - $e.Vis) * 0.35
    $a = $script:actores['E']
    if ($a) {
        $c = 1.0 - $e.Vis / 100.0
        $w = (90 + 270 * $c) * $(if ($e.Gigante) { 1.35 } else { 1.0 }); $h = $w * 114.0 / 300.0
        $suelo = 176 + 104 * $c - [Math]::Sin(($e.Hop / 8.0) * [Math]::PI) * 14
        $cx = 590 + [Math]::Sin($ahora / 1700.0) * 30 * (1 - $c)
        $a.Rect = @([int]($cx - $w / 2), [int]($suelo - $h), [int]$w, [int]$h)
    }
    $form.Invalidate()
}

# ================= SOFT FUZZY MAN (Lemon Demon · Aimkid): NECESITA SENTIR QUE EXISTE =================
# "I need to feel like I exist": la barra EXISTENCIA baja sola si nadie le hace caso y él se va volviendo transparente.
# Cada app que abres le hace caso (+12). Clic en él: tu mano le atraviesa. Clic en Orange Cat: se asusta y se sonroja.
# Cada 6 apps: "step into the mist", la niebla rosa lo llena todo.
# Tiempos (cámbialos aquí): cada cuántos ms pierde 1 de existencia
$SfTiempos = @{ Olvido = 2500; CadaNiebla = 6 }
$script:sf = $null
function Sf-Reset {
    if (-not $script:sf) {
        $script:sf = @{ Existe = 80.0; Vis = 80.0; Apps = 0; Manos = 0; Gato = 0; NieblaHasta = 0; NieblaDur = 1; NieblaTope = 150; Avisado = $false
            Prox = [Environment]::TickCount + $SfTiempos.Olvido }
    }
}
function Sf-Existir($n) {
    Sf-Reset; $e = $script:sf
    $e.Existe = [Math]::Max(0.0, [Math]::Min(100.0, $e.Existe + $n))
    if ($e.Existe -gt 30) { $e.Avisado = $false }
}
# niebla rosa que tapa el panel unos milisegundos y se va despejando; $tope = lo opaca que llega a ser (0-255)
function Sf-Niebla($ms, $tope) { Sf-Reset; $script:sf.NieblaHasta = [Environment]::TickCount + $ms; $script:sf.NieblaDur = $ms; $script:sf.NieblaTope = $tope }
# cuánta niebla espesa queda ahora (1 = toda, 0 = nada)
function Sf-Espesor { $e = $script:sf; if (-not $e) { return 0.0 }; $q = ($e.NieblaHasta - [Environment]::TickCount) / [double]$e.NieblaDur; return [Math]::Max(0.0, [Math]::Min(1.0, $q / 0.6)) }
function Sf-App($linea) {
    Sf-Reset; $e = $script:sf; $k = $script:skin
    $e.Apps++; Sf-Existir 12
    if ($e.Apps % $SfTiempos.CadaNiebla -eq 0) {
        Sf-Existir 100; Sf-Niebla 3500 150; Sonido 'viento'; Actor-Pose 'F' 'brazos' 2600
        Decir-Fijo (Azar $k.Niebla)
    } else {
        Sonido 'brillo'; Actor-Pose 'F' 'brazos' 1800; Decir $linea
    }
    $form.Invalidate()
}
function Sf-Clic {
    Sf-Reset; $e = $script:sf; $k = $script:skin
    $e.Manos++; Sf-Existir 5; Sonido 'puff'; Actor-Pose 'F' 'cara' 900
    Flotante 'FSSSH~' (600 + $Rnd.Next(-30, 30)) 90 (C 255 190 250) 20 'Segoe Print'
    Decir (Azar $k.Clic); $form.Invalidate()
}
function Sf-Gato {
    Sf-Reset; $e = $script:sf; $k = $script:skin
    $e.Gato++; Sonido 'boing'
    $a = $script:actores['G']; if ($a) { $a.Temblor = 10 }
    Flotante '<3' (480 + $Rnd.Next(-20, 20)) 110 (C 255 120 200) 14
    Decir (Azar $k.Gato); $form.Invalidate()
}
function Sf-Tick {
    Sf-Reset; $e = $script:sf; $k = $script:skin; $ahora = [Environment]::TickCount
    if ($ahora -ge $e.Prox) { $e.Prox = $ahora + $SfTiempos.Olvido; Sf-Existir -1 }
    if ($e.Existe -lt 15 -and -not $e.Avisado) { $e.Avisado = $true; Decir (Azar $k.Invisible) }
    # se ve más o menos según lo que existe, y flota de un lado a otro
    $e.Vis += ($e.Existe - $e.Vis) * 0.1
    $a = $script:actores['F']
    if ($a) {
        $a.Alfa = 0.18 + 0.82 * $e.Vis / 100.0
        $a.Rect = @([int](574 + [Math]::Sin($ahora / 2300.0) * 18), [int](64 + [Math]::Sin($ahora / 1300.0) * 6), 176, 210)
    }
    $form.Invalidate()
}
# nubes de niebla rosa que pasan despacio (de $x0 hasta el borde derecho); $fuerza de 0 a 1 (o más, más espesa)
function Pintar-Niebla($g, $x0, $W, $H, $fuerza) {
    if ($fuerza -le 0.01) { return }
    $t = [Environment]::TickCount / 1000.0
    for ($i = 0; $i -lt 7; $i++) {
        $r = 70 + ($i * 37) % 60
        $span = $W - $x0 + 2 * $r
        $x = $x0 - $r + (($i * 131 + $t * (8 + $i * 3)) % $span)
        $y = 60 + ($i * 53) % [Math]::Max(1, $H - 90) + [Math]::Sin($t * 0.7 + $i) * 10
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddEllipse([float]($x - $r * 1.4), [float]($y - $r * 0.7), [float]($r * 2.8), [float]($r * 1.4))
        $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($p)
        $br.CenterColor = [System.Drawing.Color]::FromArgb([int][Math]::Min(255, 150 * $fuerza), 255, 180, 240)
        $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 255, 180, 240))
        $g.FillPath($br, $p); $br.Dispose(); $p.Dispose()
    }
}

# ================= DISCUSIONES ENTRE ASISTENTES =================
# cada discusión es una lista de [quién, qué dice]. Solo salen las de la skin activa.
$Discusiones = @(
    , @(@('c00lgui', 'SeaDrive, tu contraseña del Wi-Fi ya es mía.'), @('SeaDrive', 'Mi contraseña es "deja de molestar". Úsala.'), @('c00lgui', '...eso ha funcionado de verdad. wtf.'), @('SeaDrive', 'Lo sé. Soy un asistente. Asisto.'))
    , @(@('Angela', 'Programa no autorizado detectado. Identifíquese.'), @('c00lgui', 'team c00lkidd. join today!'), @('Angela', 'Solicitud denegada. Iniciando contención.'), @('c00lgui', 'ok ok, me voy. por ahora.'))
    , @(@('Static Miku', '¡SeaDrive! ¡Sonríe un poquito! ¡Bzzt!'), @('SeaDrive', 'No. Sonreír gasta batería.'), @('Static Miku', '¡Pues yo sonrío por los dos!'), @('SeaDrive', 'Genial. Ahora me duele la cabeza por los dos.'))
    , @(@('SeaDrive', 'Oye, Angela. ¿Por qué lo llamas "Manager"?'), @('Angela', 'Porque es su cargo. ¿Cómo lo llama usted?'), @('SeaDrive', '"Eh, tú". Es más cercano.'), @('Angela', 'Y menos profesional. Anotado en su expediente.'))
    , @(@('Guillotina', '*Olfatea a SeaDrive de arriba abajo.*'), @('SeaDrive', 'Ni se te ocurra. Soy un asistente, no un aperitivo.'), @('Guillotina', '*Se relame.*'), @('SeaDrive', '...voy a cerrar sesión un momento.'))
    , @(@('Zodiac', '¡No te muevas, gata gorda!'), @('Guillotina', '*No se mueve. Abre la boca.*'), @('Zodiac', '*BANG*'), @('Guillotina', '*Se traga la bala. Eructa.*'), @('Zodiac', '...me voy a otro desierto.'))
    , @(@('Mikaela', 'Seis balas, vaquero. A mí con una me basta.'), @('Zodiac', 'Los duelos se hacen cara a cara, francotiradora.'), @('Mikaela', 'Por eso nunca ganas los duelos.'), @('Zodiac', '¡NO TE MUEVAS!'), @('Mikaela', '*Smokebomb.* ¿Qué decías?'))
    , @(@('c00lgui', 'inyectando aimbot en mikaela.exe...'), @('Mikaela', 'No necesito aimbot. Tengo habilidad.'), @('c00lgui', 'aimbot failed: target already too good.'), @('Mikaela', 'GG EZ.'))
    , @(@('Static Miku', '¡Hola, señor vaquero! ¿Bailamos?'), @('Zodiac', '¡NO TE MUEVAS!'), @('Static Miku', '...¿ni un poquito?'), @('Zodiac', '...bueno. Un pasito. Pero lento.'))
    , @(@('Static Miku', '¡Angela! ¡Tu programa de la tele es muy gris!'), @('Angela', 'No es un programa. Es una instalación de investigación.'), @('Static Miku', '¡Pues le faltan dibujos!'), @('Angela', '...lo propondré en la próxima reunión.'))
    , @(@('Angela', 'Anomalía felina. Regrese a su unidad de contención.'), @('Guillotina', '*Se sienta encima de la unidad de contención. La aplasta.*'), @('Angela', '...Manager, necesitaremos una unidad nueva.'))
    , @(@('Angela', 'Señorita Hawkeye, su puesto en L Corp sigue disponible.'), @('Mikaela', '¿Hay Terminators a los que disparar?'), @('Angela', 'Hay cosas peores que los Terminators.'), @('Mikaela', '...me lo pienso.'))
    , @(@('Static Miku', '¡Gatita! ¡Ven aquí, gatita!'), @('Guillotina', '*Se acerca. Mira la tele. Abre la boca.*'), @('Static Miku', '¡No, no, la antena no! ¡Bzzzzzt!'))
    , @(@('Zodiac', '¡Esa gata de los auriculares se ha movido!'), @('SeaDrive', 'Estoy respirando. Es lo que hacemos los seres vivos.'), @('Zodiac', 'Pues respira más quieta.'), @('SeaDrive', 'Increíble. Ni en mi propio panel me dejan en paz.'))
    , @(@('Zodiac', '¡Ese panel rojo parpadea! ¡Se mueve!'), @('c00lgui', 'se llama glitch, vaquero.'), @('Zodiac', '*BANG*'), @('c00lgui', '...vale, ese ha dolido.'))
    , @(@('Mikaela', 'Objetivo enorme a las doce. Fácil.'), @('Guillotina', '*Abre la boca de par en par.*'), @('Mikaela', 'Espera... ¿se va a comer la bala?'), @('Guillotina', '*ÑAM.*'))
    , @(@('c00lgui', 'hackeando la tele de Static Miku...'), @('Static Miku', '¡Hola, señor hacker! ¿Quieres ver dibujos?'), @('c00lgui', '...¿qué dibujos?'), @('Static Miku', '¡Todos! ¡Siéntate!'), @('c00lgui', '...vale. solo un episodio.'))
    , @(@('Velvet', 'Dune, cariño, ¿otra vez comiendo sin jugar con la comida?'), @('Dune', 'COMIDA ES PARA COMER.'), @('Velvet', 'Qué poco refinado eres, primo.'), @('Dune', 'GRRGH. TÚ RARA.'))
    , @(@('Velvet', 'SeaDrive, cielo, ¿vienes a mi telaraña a tomar el té?'), @('SeaDrive', 'No, gracias. Prefiero seguir vivo.'), @('Velvet', 'Qué desconfiado... me rompes el corazón.'), @('SeaDrive', 'Tienes ocho ojos y ninguno parece triste.'))
    , @(@('Zodiac', '¡No te muevas, araña!'), @('Velvet', 'Cariño, yo nunca me muevo... hasta que es tarde.'), @('Zodiac', '...eso no me ha gustado nada.'), @('Velvet', 'Seis balas. Ocho patas. Haz cuentas, vaquero.'))
    , @(@('Dune', 'GATA GORDA. ¿COMIDA?'), @('Guillotina', '*Le mira. Abre la boca.*'), @('Dune', 'NO. DUNE NO COMIDA. DUNE IRSE.'), @('Guillotina', '*Eructa satisfecha.*'))
    , @(@('Angela', 'Espécimen acuático, vuelva a su tanque.'), @('Dune', '¿TANQUE TENER COMIDA?'), @('Angela', 'No.'), @('Dune', 'ENTONCES NO.'))
    , @(@('Static Miku', '¡Hola, pececito! ¿Quieres ver dibujos?'), @('Dune', 'DIBUJOS... ¿SE COMEN?'), @('Static Miku', '¡No! ¡Se miran!'), @('Dune', 'DUNE MIRAR. DUNE ABURRIR. DUNE COMER TELE.'), @('Static Miku', '¡Bzzzzt! ¡Mi antena!'))
    , @(@('Mikaela', 'Tengo tu cabeza en la mira, araña.'), @('Velvet', 'Qué halago, cielo. Nadie me mira tan fijamente.'), @('Mikaela', 'Eso... ha sido raro.'), @('Velvet', 'Ven a verme de cerca. Te prometo que no muerdo.'))
    , @(@('c00lgui', 'hackeando a Dune...'), @('Dune', '¿QUÉ SER HACKEAR?'), @('c00lgui', 'error: no se encontró cerebro.'), @('Dune', 'GRRGH. DUNE OFENDIDO.'))
    , @(@('Zodiac', '¡Ese bicho de arena se está moviendo!'), @('Dune', 'DUNE NADAR. NADAR ES MOVERSE.'), @('Zodiac', '*BANG*'), @('Dune', '*Se traga la bala.* ÑAM. MÁS.'), @('Zodiac', '...este desierto está maldito.'))
    , @(@('Static Miku', '¡Velvet! ¡Qué voz tan bonita! ¿Cantamos juntas?'), @('Velvet', 'Claro, cielo... acércate un poquito más.'), @('Static Miku', '¡Bzzzzt! ¡Mi antena dice que no!'), @('Velvet', 'Lista, la niña. Muy lista.'))
    , @(@('SeaDrive', 'Mikaela, ¿te importa dejar de apuntarme con el láser?'), @('Mikaela', 'Es por costumbre. No es personal.'), @('SeaDrive', 'Tengo el punto rojo en la frente.'), @('Mikaela', '*Smokebomb.* Ya no lo tienes.'))
    , @(@('Angela', 'Velvet, su solicitud de empleo ha sido rechazada. Otra vez.'), @('Velvet', 'Qué pena, cielo. Me encantaba vuestra cafetería.'), @('Angela', 'Desaparecieron tres empleados de la cafetería.'), @('Velvet', '...qué casualidad, ¿verdad?'))
    # --- El Cordero y la Cabra ---
    , @(@('Velvet', 'Cordero, cielo, ¿quieres venir a mi telaraña?'), @('Cordero y Cabra', 'Cordero: *Beee.* · Cabra: Dice que no. Y yo digo que lo que quieres es cenártelo.'), @('Velvet', 'Qué cabra tan maleducada... y tan lista.'), @('Cordero y Cabra', 'Cabra: Te ofrecemos ser obispa. Con seguro dental.'), @('Velvet', 'Me lo pensaré, cariño.'))
    , @(@('Angela', 'Detecto actividad de culto no registrada en la instalación.'), @('Cordero y Cabra', 'Cabra: Lo vuestro también es un culto. Con fichaje.'), @('Angela', '...Anotado en su expediente.'), @('Cordero y Cabra', 'Cordero: *Beee.* · Cabra: Dice que tu expediente le da igual.'))
    , @(@('Dune', 'OVEJA ESPONJOSA. ¿SE COME?'), @('Cordero y Cabra', 'Cordero: *Retrocede.* · Cabra: Nadie se come al Cordero. Ese es MI trabajo.'), @('Dune', 'CABRA RARA.'), @('Cordero y Cabra', 'Cabra: *GRITA.* ¡AAAAAAAAH!'), @('Dune', 'GGRRGH. DUNE IRSE.'))
    , @(@('Zodiac', '¡No te muevas, cabra!'), @('Cordero y Cabra', 'Cabra: Si yo nunca me muevo... ¡AAAAAAAAH!'), @('Zodiac', '*BANG*'), @('Cordero y Cabra', 'Cordero: *La bala rebota en la corona.* *Beee.*'), @('Zodiac', '...me voy a otro desierto. Otra vez.'))
    # --- Pyrophina y Zaratana ---
    , @(@('Guillotina', '*Se planta delante de Pyrophina. Abre la boca.*'), @('Pyrophina y Zaratana', 'Pyrophina: ¡GRRRRRAAAARRRGH!'), @('Guillotina', '*Ruge todavía más fuerte.*'), @('Pyrophina y Zaratana', 'Zaratana: Grrrr, burp. · WMEW 99.9: ¡Tres monstruos! ¡Evacúen el pueblo!'))
    , @(@('Zodiac', '¡No os mováis, monstruos!'), @('Pyrophina y Zaratana', 'WMEW 99.9: Se mueven. Son kaijus.'), @('Zodiac', '*BANG* *BANG*'), @('Pyrophina y Zaratana', 'Pyrophina: ¡AAARGH! *Lanza a Zodiac contra Zaratana.*'), @('Zodiac', '...me duele todo.'))
    , @(@('Mikaela', 'Objetivo enorme a las doce. Dos, de hecho.'), @('Pyrophina y Zaratana', 'Zaratana: *Se mete en el caparazón. La bala rebota.*'), @('Mikaela', 'Eso no cuenta. Ha sido lag.'), @('Pyrophina y Zaratana', 'WMEW 99.9: Pyrophina le ha chamuscado las gafas a la francotiradora.'), @('Mikaela', '*Smokebomb.* Nos vemos.'))
    , @(@('Static Miku', '¡Hola, señoras dinosaurio! ¿Bailamos?'), @('Pyrophina y Zaratana', 'Pyrophina: ¡GRRRRRAAAARRRGH!'), @('Static Miku', '¡Eso es un sí! ¡Un, dos, tres!'), @('Pyrophina y Zaratana', 'WMEW 99.9: Zaratana ha pisado la antena. Se acabó el baile.'), @('Static Miku', '¡Bzzzzzt! ¡Mi antena!'))
    , @(@('Angela', 'Anomalías de clase kaiju, diríjanse a contención.'), @('Pyrophina y Zaratana', 'Pyrophina: ¡GRRRRRAAAARRRGH! · Zaratana: ¡GRRRR, GRRRRR!'), @('Angela', 'Manager, necesitaremos una unidad de contención... mucho más grande.'))
    , @(@('Cordero y Cabra', 'Cabra: Oye, lagartija gigante. Únete al culto.'), @('Pyrophina y Zaratana', 'Pyrophina: ¡AAARGH! *Quema el templo.*'), @('Cordero y Cabra', 'Cordero: *Mira el templo arder.* *Beee.*'), @('Pyrophina y Zaratana', 'Zaratana: Grrrr, burp. · WMEW 99.9: Zaratana se ha comido las ruinas.'))
    # --- Averi ---
    , @(@('Averi', '¡SeaDrive! ¡Hoy tienes cara de muy cansada!'), @('SeaDrive', '...gracias. Supongo.'), @('Averi', '¡No! ¡Quería decir guapa! ¡Guapa de forma cansada!'), @('SeaDrive', 'Eso no existe. Pero vale. Te perdono.'))
    , @(@('Averi', '¿Quieres un sándwich de pollo, gatita?'), @('Guillotina', '*Se lo traga. Y la bolsa. Y la mesa.*'), @('Averi', '...¿y ahora qué como yo?'), @('Guillotina', '*Mira a Averi y se relame.*'), @('Averi', '¡Voy a por más sándwiches! ¡Rapidísimo!'))
    , @(@('Zodiac', '¡No te muevas, zorra!'), @('Averi', '*Le da un abrazo.*'), @('Zodiac', '...¿qué haces?'), @('Averi', '¡Pareces estresado! Toma, un sándwich.'), @('Zodiac', '...gracias. No se lo digas a nadie.'))
    , @(@('Velvet', 'Zorrita, ¿vienes a cenar a mi telaraña?'), @('Averi', '¡Claro! ¿Qué hay de cena?'), @('Velvet', 'Tú, cielo.'), @('Averi', '¡Ah! ¡Me acabo de acordar de que tengo que irme! ¡Adiós!'))
    , @(@('Averi', '¡Zaratana! ¡Eres una piedrita muy bonita!'), @('Pyrophina y Zaratana', 'Zaratana: *Se mete en el caparazón. Le da vergüenza.*'), @('Averi', '¡Pyrophina, tú también eres muy guapa!'), @('Pyrophina y Zaratana', 'Pyrophina: ¡GRRRRRAAAARRRGH! · WMEW 99.9: Le ha gustado. Creo.'))
    , @(@('Averi', '¡Hola, Cordero! ¡Qué lana tan suave!'), @('Cordero y Cabra', 'Cordero: *Beee.* · Cabra: Dice gracias. Yo digo: no toques la corona.'), @('Averi', '¿Puedo entrar en vuestro culto si traigo sándwiches?'), @('Cordero y Cabra', 'Cabra: ...Con eso ya eres obispa.'))
    , @(@('c00lgui', 'hackeando a averi...'), @('Averi', '¡Hola, c00lgui! ¿Quieres ser mi amigo?'), @('c00lgui', 'error: amistad no autorizada.'), @('Averi', '¡Te hago un sándwich y la autorizas!'), @('c00lgui', '...ok. amistad.exe instalado.'))
    , @(@('Mikaela', 'Averi, apunta a la lata. Respira. Dispara.'), @('Averi', '*Dispara.* ¡Le he dado!'), @('Mikaela', 'Le has dado a la lámpara. Otra vez.'), @('Averi', '¡Pero con mucha puntería!'))
    # --- Sebastian Solace ---
    , @(@('Pursuer', '*Huele la tienda.* ...carne fresca.'), @('Sebastian Solace', 'Eh, eh, eh. Aquí no se come al dependiente, amigo.'), @('Pursuer', '...¿Y a los clientes?'), @('Sebastian Solace', 'Los clientes... hmm. Eso lo negociamos.'))
    , @(@('Zodiac', '¡No te muevas, pez!'), @('Sebastian Solace', 'Amigo, llevo tres horas sin moverme del mostrador.'), @('Zodiac', '...¿Vendes balas?'), @('Sebastian Solace', 'Seis balas, seis de investigación. Pagas primero.'))
    , @(@('c00lgui', 'hackeando sebastian_shop.exe...'), @('Sebastian Solace', '¡Ja! Mi caja registradora es analógica, amigo.'), @('c00lgui', 'error: tienda demasiado vieja.'), @('Sebastian Solace', 'Y aun así te cobro la visita.'))
    , @(@('Angela', 'Detecto un comercio no autorizado en la instalación.'), @('Sebastian Solace', 'Lo autorizo yo. Problema resuelto.'), @('Angela', 'Así no funcionan las cosas, señor Solace.'), @('Sebastian Solace', 'Aquí abajo, sí.'))
    , @(@('Averi', '¡Hola! ¿Tienes sándwiches de pollo?'), @('Sebastian Solace', 'Tengo pilas, linternas y botiquines.'), @('Averi', '...¿y las pilas saben a pollo?'), @('Sebastian Solace', 'Por el amor de dios. Toma una linterna. Gratis. Vete.'))
    , @(@('Cordero y Cabra', 'Cabra: Oye, pez. ¿Cuánto por la tienda entera?'), @('Sebastian Solace', 'No está en venta. Como vuestra alma, supongo.'), @('Cordero y Cabra', 'Cabra: Nuestra alma sí está en venta.'), @('Sebastian Solace', '...me gusta este cliente.'))
    , @(@('Guillotina', '*Se come una caja de pilas del mostrador.*'), @('Sebastian Solace', '¡Eh! ¡Eso se paga!'), @('Guillotina', '*Eructa una chispa.*'), @('Sebastian Solace', '...apuntado en tu cuenta. Con intereses.'))
    # --- Kasane Teto ---
    , @(@('Kasane Teto', '¡Hiii, Miku! ¿Cantamos?'), @('Static Miku', '¡Teto! ¡Pero tú eras una broma del uno de abril!'), @('Kasane Teto', 'Sí. Y aquí sigo. La broma es muy larga.'), @('Static Miku', '¡Bzzt! ¡Vale! ¡Pero yo hago la voz principal!'))
    , @(@('Kasane Teto', '¡Hiii! ¿Tienes pan francés?'), @('Sebastian Solace', 'Tengo pilas, linternas y botiquines.'), @('Kasane Teto', '...¿y una linterna con forma de baguette?'), @('Sebastian Solace', 'Por el amor de dios. Toma una linterna normal y vete.'))
    , @(@('Pursuer', '*Huele el aire.* ...carne fresca.'), @('Kasane Teto', '¡Hiii~!'), @('Pursuer', '...¿hiii?'), @('Kasane Teto', '¡Hiii! ¡Es lo que se dice para saludar!'), @('Pursuer', '*Se va al bosque muy confundido.*'))
    , @(@('Averi', '¡Teto! ¿Me enseñas tu baile?'), @('Kasane Teto', '¡Claro! Primero, olvídate de todo.'), @('Averi', '...ya está. ¿Y ahora?'), @('Kasane Teto', '¿Ahora qué? ...¡ay, se me ha olvidado a mí también!'))
    , @(@('Guillotina', '*Mira las coletas de Teto. Se relame.*'), @('Kasane Teto', '¡No son pan! ¡Son taladros!'), @('Guillotina', '*Abre la boca igualmente.*'), @('Kasane Teto', '¡Toma, toma! *Le lanza la baguette y sale corriendo.*'))
    # --- Pursuer ---
    , @(@('Mikaela', 'Objetivo localizado. ...¿Dónde se ha metido?'), @('Pursuer', '...te veo.'), @('Mikaela', '*Smokebomb.* Ahora yo tampoco te veo a ti.'), @('Pursuer', '*Huele el humo.* No me hace falta verte.'))
    , @(@('Static Miku', '¡Hola, señor de la armónica! ¿Tocamos juntos?'), @('Pursuer', '*Toca una nota triste.*'), @('Static Miku', '¡Qué bonito! ...¿por qué me miras así?'), @('Pursuer', '...carne fresca.'), @('Static Miku', '¡BZZZZT! ¡Cambio de canal!'))
    , @(@('Guillotina', '*Olfatea a Pursuer.*'), @('Pursuer', 'Tú comes carne vieja.'), @('Guillotina', '*Le eructa en la cara.*'), @('Pursuer', '...asquerosa.'))
    , @(@('Pursuer', '*Mira fijamente al Cordero.* ...carne fresca.'), @('Cordero y Cabra', 'Cordero: *Beee.* · Cabra: Ni se te ocurra, lobito.'), @('Pursuer', '*Desaparece entre los árboles.*'), @('Cordero y Cabra', 'Cabra: ...¿Dónde se ha ido? Cordero, ponte detrás de mí.'))
    , @(@('Velvet', '¿Te apetece cenar conmigo, cazador?'), @('Pursuer', '¿Fresco?'), @('Velvet', 'Recién atrapado en mi telaraña, cielo.'), @('Pursuer', '...voy.'))
    , @(@('Dune', 'COSA BOSQUE. ¿AMIGO?'), @('Pursuer', '...no.'), @('Dune', 'DUNE IRSE NADANDO. MUY RÁPIDO.'))
    , @(@('Token', '¡H3Y, TETRA! ¿Breakcore?'), @('Tetra', 'Estoy en No molestar.'), @('Token', '*Sube el volumen.*'), @('Tetra', '*Se pone los cascos.* ...vale, esto suena bien.'), @('Token', '¡LO SABÍA!'))
    , @(@('Tetra', 'Hey, SeaDrive. Somos del mismo creador, ¿no?'), @('SeaDrive', 'Eso dicen. ¿Y?'), @('Tetra', 'Nada. Solo quería decirlo.'), @('SeaDrive', 'Vale. ...esto ha sido agradable. No se lo digas a nadie.'))
    , @(@('Kasane Teto', '¡Hiii, Tetra!'), @('Tetra', 'Hey.'), @('Kasane Teto', '¡Me has contestado! ¡Somos mejores amigos!'), @('Tetra', '...vale. Por qué no.'))
    , @(@('Token', 'c00lgui, hackea el volumen. Que llegue al 11.'), @('c00lgui', 'done. ahora va al 12.'), @('Token', '¡¡SÍ!!'), @('c00lgui', 'tus vecinos me odian. bien.'))
    , @(@('Pursuer', 'Carne... ¿fresca?'), @('Token', 'Soy de plástico. Y estoy sonando a 200 BPM.'), @('Pursuer', '*Se tapa las orejas.* ...me voy.'))
    , @(@('Zodiac', '¡No te muevas!'), @('Token', '*Vibra a 180 BPM.*'), @('Zodiac', '¡HE DICHO QUE NO TE MUEVAS!'), @('Token', 'No puedo. Es el bajo.'), @('Zodiac', '*BANG* ...¿sigue sonando? Esto es brujería.'))
    , @(@('Mikaela', 'Tetra, ¿una partida?'), @('Tetra', 'Vale. Pero algo tranquilo.'), @('Mikaela', '360 noscope.'), @('Tetra', '...vale, he perdido. Me hago unos fideos.'))
    , @(@('Averi', '¡Tetra! ¡Te he mandado cuarenta stickers!'), @('Tetra', 'Lo sé. Los he visto todos.'), @('Averi', '¿Y por qué no contestas?'), @('Tetra', '*Le manda un sticker.*'), @('Averi', '¡¡CONTESTÓ!!'))
    , @(@('Enfosi', 'Glaggle sospechoso a la vista: blanco, sin símbolo en la camiseta...'), @('Token', 'Soy Token. Una ficha. No un Glaggle.'), @('Enfosi', '...eso es justo lo que diría un Enphosian.'), @('Token', '*Sube el volumen.* ¿Te lo dice esto?'))
    , @(@('Zodiac', '¡No te muevas, Glaggle!'), @('Enfosi', '¡Cuidado! Ese era un Giggler inocente.'), @('Zodiac', '*BANG* ...¿cómo que inocente?'), @('Enfosi', 'Strike. Y viene el Ojo de Enphoso a por ti.'), @('Zodiac', '...me voy a otro desierto.'))
    , @(@('Averi', '¡Qué Glaggles tan monos! ¡Voy a abrazarlos a todos!'), @('Enfosi', 'Ese Cheerer lleva el regalo un poco raro...'), @('Averi', '*Lo abraza.*'), @('Enfosi', '*El regalo explota.* ...era un Enphosian.'), @('Averi', '¡Estoy bien! ¡Huelo a confeti!'))
    , @(@('Enfosi', 'Un Glaggle verde con un cartel. ¿Gloober de verdad?'), @('Kevin', '¿Lleva pizza? ¡Si lleva pizza es MÍA!'), @('Enfosi', 'Lleva un Gloobnut. Es un donut.'), @('Kevin', '...vale. Puede pasar.'))
    , @(@('Mikaela', 'Dame un objetivo. El que sea.'), @('Enfosi', 'El Gazo de la izquierda. Fíjate: su símbolo es falso.'), @('Mikaela', '*Headshot.* ¡Hitmarker!'), @('Enfosi', '¡Enphosian eliminado! Así se juega.'))
    , @(@('Zodiac', '¡No te muevas, bicho del bosque!'), @('Pursuer', '*Se vuelve invisible.*'), @('Zodiac', '¿¡Dónde está!? ¡NO TE MUEVAS, DONDE SEA QUE ESTÉS!'), @('Pursuer', '*Detrás de él.* ...te veo.'))
    # --- Kevin (Don't Touch My Pizza) ---
    , @(@('Guillotina', '*Mira la pizza de Kevin. Abre la boca.*'), @('Kevin', '¡¡NO TOQUES MI PIZZA!! *Saca un cuchillo.*'), @('Guillotina', '*Se traga el cuchillo. Eructa.*'), @('Kevin', '...vale. Saco la motosierra.'), @('Guillotina', '*Se aleja muy despacio.*'))
    , @(@('Dune', 'PIZZA. DUNE COMER PIZZA.'), @('Kevin', 'DUNE NO COMER PIZZA. DUNE IRSE.'), @('Dune', '¿POR QUÉ TÚ HABLAR COMO DUNE?'), @('Kevin', 'PARA QUE ENTIENDAS. NO. TOQUES. MI. PIZZA.'), @('Dune', 'GRRGH. DUNE ENTENDER. DUNE TRISTE.'))
    , @(@('Zodiac', '¡No te muevas, lobo verde!'), @('Kevin', 'No me muevo. Estoy comiendo. *ÑAM.*'), @('Zodiac', '...¿me das un trozo?'), @('Kevin', '¡¡DON''T TOUCH MY PIZZA!!'), @('Zodiac', '*BANG* ...a la pizza no le ha pasado nada. Es inmortal.'))
    , @(@('Averi', '¡Kevin! ¡Te cambio medio sándwich de pollo por un trozo de pizza!'), @('Kevin', '...¿medio? ¿Por qué medio?'), @('Averi', '¡Porque la otra mitad ya me la he comido!'), @('Kevin', 'Trato. Pero no toques la pizza. Te lo doy yo con la mano.'))
    , @(@('Kevin', '¡Token! ¡Hazme un remix!'), @('Token', '¿De qué?'), @('Kevin', '¡DE "NO TOQUES MI PIZZA"!'), @('Token', '*Sube el volumen a 200 BPM.* DON''T TOUCH MY PIZZA. DROP.'), @('Kevin', '*Baila como un loco.* ¡ESTO ES ARTE!'))
    , @(@('Mikaela', 'Objetivo verde con pizza. Fácil.'), @('Kevin', 'Si le das a la pizza, te muerdo. Y no es broma.'), @('Mikaela', '*Dispara. Falla a propósito.* Era un aviso.'), @('Kevin', '*Se cubre la pizza con el cuerpo.* Era un aviso para TI.'))
    , @(@('Kevin', '¿Alguien ha visto mi mermelada?'), @('Kasane Teto', '¡Me la he comido con baguette! ¡Estaba buenísima!'), @('Kevin', '...NO TOQUES MI MERMELADA.'), @('Kasane Teto', '¡Pero si ya no está! ¡No se puede tocar lo que no existe!'), @('Kevin', '*Saca la motosierra.* ¡HE DICHO QUE NO!'))
    , @(@('Angela', 'Kevin, la cafetería informa de que falta una pizza entera.'), @('Kevin', 'No sé de qué me hablas. *Tiene queso en la cara.*'), @('Angela', 'Tiene queso en la cara.'), @('Kevin', 'Es... crema facial. De pepperoni.'))
    , @(@('Kevin', '¡Pursuer! ¿Quieres pizza?'), @('Pursuer', '...¿carne fresca?'), @('Kevin', 'Pepperoni. Es casi carne. Más o menos.'), @('Pursuer', '*La huele. Se va al bosque decepcionado.*'), @('Kevin', 'Más para mí. *ÑAM.*'))
    , @(@('Sebastian Solace', 'Amigo, ¿me vendes un trozo? Te pago en investigación.'), @('Kevin', 'La pizza no se vende, no se toca y no se mira mucho rato.'), @('Sebastian Solace', 'Te doy una linterna, unas pilas y un botiquín.'), @('Kevin', '...ni por todo el Hadal Blacksite. NO TOQUES MI PIZZA.'))
    , @(@('Velvet', 'Kevin, cielo, ¿cenamos juntos?'), @('Kevin', '¿Qué hay de cena?'), @('Velvet', 'Lo que caiga en mi telaraña, cariño.'), @('Kevin', 'Yo traigo pizza. Mi pizza. Y no la toca nadie. Y me siento lejos de la telaraña.'))
    # --- Kennyoung ---
    , @(@('Kennyoung', 'Hey, Tetra. ¿Has escuchado mi última canción?'), @('Tetra', 'Me la pasaste hace dos semanas.'), @('Kennyoung', '¿Y?'), @('Tetra', 'La tengo en "pendientes". ...es broma. La he puesto doce veces.'), @('Kennyoung', '*Rasguea un acorde de felicidad.*'))
    , @(@('SeaDrive', 'Kenny, ¿podrías tocar más bajo?'), @('Kennyoung', 'Esto ES más bajo.'), @('SeaDrive', 'Se oye desde la otra punta del escritorio.'), @('Kennyoung', 'Es pop-punk. Si no se oye desde la otra punta, no cuenta.'))
    , @(@('Token', '¡KENNY! ¿Un dueto? Tú guitarra, yo 200 BPM.'), @('Kennyoung', 'Vale. Uno, dos, tres, cuatro...'), @('Token', '*Sube el volumen al máximo.*'), @('Kennyoung', '*La guitarra EXPLOTA.* ...ha sido el mejor dueto de mi vida.'))
    , @(@('Kasane Teto', '¡Hiii, Kenny! ¿Hacemos un cover?'), @('Kennyoung', 'Vale. ¿Te sabes la letra?'), @('Kasane Teto', '¡No! ¿Y tú?'), @('Kennyoung', 'Tampoco. Perfecto. Cantamos el estribillo cinco veces y ya.'))
    , @(@('Kevin', '¡Kenny! ¡Hazme una canción sobre mi pizza!'), @('Kennyoung', 'Vale. *Rasguea.* "No toques su pizza~"'), @('Kevin', '¡¡SÍ!! ¡ESO! ¡MÁS FUERTE!'), @('Kennyoung', '*Toca más fuerte. El ampli EXPLOTA.*'), @('Kevin', '...la pizza ha sobrevivido. Eres de los buenos.'))
    , @(@('Zodiac', '¡No te muevas, músico!'), @('Kennyoung', 'Estoy en pleno solo de guitarra, tío.'), @('Zodiac', '¡HE DICHO QUE NO TE MUEVAS!'), @('Kennyoung', '*Sigue tocando.* ¿Sabes qué? Esto mola. Tú dispara al ritmo.'), @('Zodiac', '*BANG* *BANG* ...oye, esto suena bien.'))
    , @(@('Guillotina', '*Mira la guitarra de Kenny. Abre la boca.*'), @('Kennyoung', 'No. No, no, no. Esa es la buena.'), @('Guillotina', '*Se la traga.*'), @('Kennyoung', '...toca un acorde desde dentro, por favor.'), @('Guillotina', '*Eructa en Do mayor.*'))
    , @(@('Angela', 'Kennyoung, los empleados se quejan del ruido.'), @('Kennyoung', '¿Del ruido o de la música?'), @('Angela', 'No he sabido diferenciarlos.'), @('Kennyoung', 'Eso es pop-punk. Funciona.'))
    , @(@('c00lgui', 'hackeando el canal de kennyoung...'), @('Kennyoung', 'Ah, hola. ¿Me subes el vídeo que tengo a medias? Me da pereza.'), @('c00lgui', '...¿quieres que te lo suba?'), @('Kennyoung', 'Sí. Y ponle una miniatura chula.'), @('c00lgui', 'ok. esto no es hackear. esto es trabajar. me voy.'))
    , @(@('Static Miku', '¡Kenny! ¡Bzzt! ¡Quiero ser tu cantante!'), @('Kennyoung', '¿Sabes cantar pop-punk?'), @('Static Miku', '¡AAAAAH! ¡ASÍ! ¿VALE?'), @('Kennyoung', '...vale. Estás contratada. Es exactamente así.'))
    , @(@('Pursuer', '*Escucha la guitarra desde el bosque.*'), @('Kennyoung', 'Hey. ¿Quieres tocar? Tengo una armónica de sobra.'), @('Pursuer', '...*Toca una nota.*'), @('Kennyoung', 'Eso ha sonado muy triste. Me encanta. Ya tenemos canción.'))
    , @(@('c00lgui', 'hackeando kevin.png...'), @('Kevin', '¡Eh! ¡Ese es MI Paint!'), @('c00lgui', 'borrando pizza.bmp...'), @('Kevin', '¡¡NO TOQUES MI PIZZA!! *Le muerde el cable del teclado.*'), @('c00lgui', '...ok ok. acceso denegado. por miedo.'))
    , @(@('Gran', 'SeaDrive. Orejas, cola, cansancio crónico. Es usted casi un sujeto ideal.'), @('SeaDrive', '¿Casi?'), @('Gran', 'Le falta firmar.'), @('SeaDrive', 'No pienso firmar nada que no sea mi baja.'))
    , @(@('Gran', 'c00lgui. Intente hackear mi laboratorio otra vez.'), @('c00lgui', 'ya estoy dentro. tu contraseña es "furry123".'), @('Gran', 'Era un señuelo. Acaba de descargarse la vacuna.'), @('c00lgui', '...error. error. ¿por qué me pica la carcasa?'))
    , @(@('Angela', 'Doctor Gran, su empresa crea anomalías sin licencia.'), @('Gran', 'Ustedes las encierran. Yo les doy una vida mejor.'), @('Angela', 'Eso no figura en ningún protocolo.'), @('Gran', 'Todavía.'))
    , @(@('Gran', 'Kasane Teto. Sigue siendo humana. ¿Por qué?'), @('Kasane Teto', '¡Porque me gusta! ¡Tengo coletas! ¡Son como orejas!'), @('Gran', 'No son orejas.'), @('Kasane Teto', '¡Son orejas de taladro!'), @('Gran', '...lo anoto como "caso perdido".'))
    , @(@('Averi', '¡Hola, doctor! ¿Quiere un sándwich?'), @('Gran', 'No. ¿Quiere ser mi sujeto número tres?'), @('Averi', '¿Eso tiene sándwich?'), @('Gran', 'Tiene contrato.'), @('Averi', '...me quedo con el sándwich.'))
    , @(@('Kevin', '¡ALEJA ESA JERINGUILLA DE MI PIZZA!'), @('Gran', 'No quiero su pizza. Quiero su ADN.'), @('Kevin', '¡¿Y EL ADN ESTÁ EN LA PIZZA?!'), @('Gran', 'Ahora sí. Se le ha caído pelo encima.'), @('Kevin', '¡NOOOOO!'))
    , @(@('Gran', 'Kennyoung. Esa canción del ascensor... ¿la ha tocado usted?'), @('Kennyoung', '¿"Are You Sure He''s a Pharmacist"? No, esa es de ivycomb.'), @('Gran', 'Ah. Pensé que era sobre mí.'), @('Kennyoung', '...lo es. Por eso no la toco.'))
    , @(@('Guillotina', '*Olfatea la bata de Gran.*'), @('Gran', 'Quieta. Es usted una anomalía muy interesante.'), @('Guillotina', '*Se come la jeringuilla.*'), @('Gran', '...dosis administrada. De una forma poco ortodoxa.'))
    , @(@('Gran', 'Tetra. Gato. Tranquilo. Es usted lo que quiero para todos.'), @('Tetra', 'Gracias. ...¿puedo seguir en el sofá?'), @('Gran', 'Toda la especie superior debería estar en el sofá.'), @('Tetra', 'Por fin alguien que lo entiende.'))
    , @(@('Pursuer', '*Huele a Gran desde el bosque. No huele a presa.*'), @('Gran', 'No soy humano. No me interesa usted. Tráigame humanos.'), @('Pursuer', '...¿y qué gano yo?'), @('Gran', 'Que lleguen con cola. Son más fáciles de atrapar.'))
    # --- Nanachi (Made in Abyss) ---
    , @(@('Gran', 'Un sujeto con orejas de conejo. Fascinante. ¿Quién te hizo esto?'), @('Nanachi', '*Se le eriza el pelo.* Alguien como tú. No te acerques.'), @('Gran', 'Solo quiero una muestra de sangre. Pequeñita.'), @('Nanachi', 'Ya me sacaron bastante sangre una vez. ¡Nnaa! *Le tira el cucharón.*'))
    , @(@('Angela', 'Espécimen no catalogado. ¿Nivel de riesgo?'), @('Nanachi', 'Nnaa... no soy un espécimen. Soy Nanachi.'), @('Angela', 'Anotado: "Nanachi". Nivel de riesgo: mullido.'), @('Nanachi', '...esa palabra otra vez. Te odio un poquito.'))
    , @(@('Dune', 'DUNE OLER COMIDA. ¿QUÉ SER?'), @('Nanachi', 'Estofado del Abismo. Pez demonio, huevo y hierba pegajosa.'), @('Dune', '*Se lo come todo.* ÑAM. DUNE QUERER MÁS.'), @('Nanachi', '...es la primera vez que alguien repite. Nnaa~ Te quiero un poco.'))
    , @(@('Kevin', '¿Eso es estofado? ¿Me das? Yo te doy... nada. La pizza no se toca.'), @('Nanachi', 'No pasa nada. Mi estofado tampoco te lo comerías.'), @('Kevin', '*Lo prueba.* ¡PUAJ! ¡Sabe peor que el queso azul!'), @('Nanachi', 'Lo sé. Es un don. Nnaa.'))
    , @(@('Averi', '¡Nanachi! ¡Qué pelo tan mullido! ¿Puedo tocarte?'), @('Nanachi', 'No.'), @('Averi', '*Le abraza igualmente.* ¡Hueles a algodón de azúcar!'), @('Nanachi', '...Nnaa. Cinco segundos. Ni uno más.'))
    , @(@('Guillotina', '*Olfatea el estofado. Abre la boca.*'), @('Nanachi', 'Es estofado del Abismo. Nadie se lo come entero.'), @('Guillotina', '*Se lo traga. Con la olla. Eructa.*'), @('Nanachi', '...vale. Retiro lo dicho. Nnaa.'))
    , @(@('Pursuer', '*Huele el aire.* ...carne fresca.'), @('Nanachi', 'Aquí no hay carne fresca. Hay estofado de hace tres días.'), @('Pursuer', '*Lo prueba.* ...'), @('Nanachi', '*Pursuer se va al bosque muy despacio.* Ni los cazadores lo aguantan.'))
    , @(@('Sebastian Solace', 'Amigo, ¿me vendes uno de esos antídotos tuyos?'), @('Nanachi', 'Están hechos con setas de la 4ª capa. ¿Qué me das?'), @('Sebastian Solace', 'Una linterna, unas pilas y un descuento.'), @('Nanachi', 'Trato. En el Abismo una linterna vale más que el oro.'))
    , @(@('Kennyoung', 'Hey, Nanachi. ¿Te molesta si toco algo?'), @('Nanachi', 'Si es bajito, no.'), @('Kennyoung', '*Toca un acorde muy suave.*'), @('Nanachi', '*Cierra los ojos.* ...vale. Sigue. Solo un rato.'))
    , @(@('Zodiac', '¡No te muevas, conejo!'), @('Nanachi', 'No soy un conejo. Y en el Abismo, si no te mueves, te comen.'), @('Zodiac', '*BANG*'), @('Nanachi', '*Le cura la quemadura del dedo.* Sujetaste el revólver al revés. Nnaa.'))
    , @(@('Kasane Teto', '¡Hiii, Nanachi! ¿Cambiamos baguette por estofado?'), @('Nanachi', 'Te vas a arrepentir.'), @('Kasane Teto', '*Lo prueba.* ...¡se me ha olvidado cómo se respira!'), @('Nanachi', 'Es normal. Bebe agua. Mucha.'))
    , @(@('Velvet', 'Qué cosita tan mullida. ¿Cenas conmigo, cariño?'), @('Nanachi', 'Conozco esa sonrisa. La he visto en bichos de la 5ª capa.'), @('Velvet', 'Qué desconfianza... me encanta.'), @('Nanachi', 'Nnaa. Yo cocino. Tú no te acercas. Así cenamos todos.'))
    # --- Evil Scary (Die of Death) · Halloween ---
    , @(@('Pursuer', '*Huele el aire.* ...carne fresca.'), @('Evil Scary', '*Bota una vez. Más cerca.*'), @('Pursuer', '...no. Esa carne no. *Se vuelve invisible.*'), @('Evil Scary', 'IT IS EVIL AND SCARY. *Lo encuentra igual. Ve a través de todo.*'))
    , @(@('Zodiac', '¡NO TE MUEVAS!'), @('Evil Scary', '*Bota hacia él.*'), @('Zodiac', '*BANG* *BANG* *BANG* ...¡no le hace nada!'), @('Evil Scary', 'STALL. STALL.'), @('Zodiac', '¡ME VOY A OTRO DESIERTO!'))
    , @(@('Kevin', '¡EH! ¡NO TOQUES MI PIZZA!'), @('Evil Scary', '*Bota. No mira la pizza. Mira a Kevin.*'), @('Kevin', '...vale. Puedes quedártela. ¡QUÉDATELA!'), @('Evil Scary', '*Sigue botando hacia Kevin. La pizza le da igual.*'))
    , @(@('Dune', 'BOLA NEGRA. ¿COMIDA?'), @('Evil Scary', '*Sonríe más.*'), @('Dune', 'NO COMIDA. DUNE COMIDA. DUNE IRSE NADANDO.'))
    , @(@('Gran', 'Un sujeto sin cuerpo. Solo manos y una sonrisa. Fascinante.'), @('Evil Scary', '*Bota hacia la jeringuilla.*'), @('Gran', 'Quieto. Solo es una muestra. *La jeringuilla se queda negra.*'), @('Evil Scary', 'IT IS EVIL AND SCARY.'))
    , @(@('Nanachi', 'Nnaa. Paso de todo.'), @('Evil Scary', '*Bota hacia Nanachi.*'), @('Nanachi', '...menos de esto. *Se levanta por primera vez en todo el día.*'), @('Evil Scary', 'STALL. STALL.'), @('Nanachi', '¡CORRE, MITTY! ...vale, Mitty no corre. Te llevo yo.'))
    , @(@('Averi', '¡Hola, bolita! ¿Quieres un abrazo?'), @('Evil Scary', '*Se queda quieto. Nadie le había ofrecido un abrazo.*'), @('Averi', '*Le abraza.*'), @('Evil Scary', '*...bota hacia atrás. Muy confundido.*'))
    , @(@('Angela', 'Entidad hostil detectada. Iniciando contención.'), @('Evil Scary', '*Atraviesa la pared de la celda.*'), @('Angela', '...Manager, necesitaremos paredes que no se puedan atravesar.'), @('Evil Scary', 'IT IS EVIL AND SCARY.'))
    , @(@('Token', '¡H3Y! ¿Breakcore?'), @('Evil Scary', 'STALL. STALL.'), @('Token', '*Mete la alarma en un remix a 200 BPM.*'), @('Evil Scary', '*Bota al ritmo. Más rápido.*'), @('Token', '...vale, esto ha sido mala idea.'))
    , @(@('Mikaela', 'Objetivo localizado. 360 noscope.'), @('Evil Scary', '*No le pasa nada.*'), @('Mikaela', '...¿lag? *Smokebomb.*'), @('Evil Scary', '*Lo ve a través del humo. Y de las paredes.*'))
    # --- Soft Fuzzy Man (Lemon Demon · Aimkid) · Halloween ---
    , @(@('Evil Scary', '*Bota hacia la niebla rosa.*'), @('Soft Fuzzy Man', 'Hola, guapo. ¿Vienes mucho por aquí?'), @('Evil Scary', 'IT IS EVIL AND SCARY.'), @('Soft Fuzzy Man', '*Evil Scary le atraviesa. Él atraviesa a Evil Scary.* ...esto es lo más cerca que he estado de alguien en meses.'))
    , @(@('Averi', '¡Qué nube tan bonita! ¿Te puedo abrazar?'), @('Soft Fuzzy Man', 'Puedes intentarlo.'), @('Averi', '*Le abraza. Le atraviesa. Le vuelve a abrazar.* ¡Hueles a algodón de azúcar!'), @('Soft Fuzzy Man', '*Se pone rosa fuerte.* ...nadie había insistido tanto.'))
    , @(@('Kevin', '¡EH! ¡Estás encima de mi pizza!'), @('Soft Fuzzy Man', 'Estoy DENTRO de tu pizza. No es lo mismo. No la toco.'), @('Kevin', '¡Pues ahora sabe a niebla!'), @('Soft Fuzzy Man', 'De nada. Es un sabor muy sofisticado.'))
    , @(@('Pursuer', '*Huele el aire.* ...carne fresca.'), @('Soft Fuzzy Man', 'Lo siento, cariño. Aquí todo es niebla.'), @('Pursuer', '*Muerde. Muerde aire rosa.*'), @('Soft Fuzzy Man', 'Los dos somos lobos. Yo he evolucionado.'))
    , @(@('Gran', 'Un sujeto sin cuerpo. Fascinante. Una muestra, por favor.'), @('Soft Fuzzy Man', 'Claro. Sírvete.'), @('Gran', '*La jeringuilla se llena de niebla rosa. Se le escapa por la aguja.*'), @('Soft Fuzzy Man', 'No me puedes convertir en nada. Ya me pasó algo peor.'))
    , @(@('Angela', 'Entidad gaseosa detectada. Procediendo a su contención.'), @('Soft Fuzzy Man', '*Se cuela por la rejilla de ventilación.* ¿Decías algo?'), @('Angela', 'Manager, necesitamos celdas herméticas.'), @('Soft Fuzzy Man', 'Me encanta tu voz. Es tan... sólida.'))
    , @(@('Velvet', 'Qué cosita tan brillante. ¿Cenas conmigo, cielo?'), @('Soft Fuzzy Man', 'No como. Pero me encantaría flotar a tu lado.'), @('Velvet', '*Le teje una telaraña. La atraviesa.* ...qué difícil eres.'), @('Soft Fuzzy Man', 'Es mi encanto. Soy un misterio.'))
    , @(@('Zodiac', '¡NO TE MUEVAS!'), @('Soft Fuzzy Man', 'No me muevo. Floto.'), @('Zodiac', '*BANG* *BANG* ...¡LAS BALAS LE ATRAVIESAN!'), @('Soft Fuzzy Man', 'Me has disparado. Me has visto. Gracias, vaquero.'))
    , @(@('Static Miku', '¡Bzzt! ¡Eres borroso como mi tele!'), @('Soft Fuzzy Man', 'Somos de la misma familia: tú haces "fsssh" y yo hago "fsssh".'), @('Static Miku', '¡Vamos a cantar juntos! ¡Bzzt!'), @('Soft Fuzzy Man', '"Lo que necesitas es un hombre suave y esponjoso..." *Bzzt.* Qué buen dúo.'))
    , @(@('Nanachi', '...nnaa. Huele a algodón de azúcar.'), @('Soft Fuzzy Man', 'Soy yo. Hola, cosa mullida.'), @('Nanachi', 'En el Abismo hay niebla que mata. ¿Tú matas?'), @('Soft Fuzzy Man', 'Yo solo ligo.'), @('Nanachi', '...eso es peor. Nnaa.'))
)

$script:discutiendo = $false; $script:dLineas = $null; $script:dIdx = 0; $script:dImg = $null; $script:dInvitadoHabla = $false
$script:dFin = 0; $script:dUltima = $null
$script:inv = $null; $script:invSkin = $null; $script:invNombre = $null; $script:invPb = $null; $script:invLbl = $null
$script:invTexto = ''; $script:invPos = 0; $script:invFx = 0; $script:invAnim = 0; $script:invLado = 1; $script:invSale = $false
$script:invEst = 0; $script:invRuido = $null
$dTimer = New-Object System.Windows.Forms.Timer
$dTimer.Add_Tick({ Paso-Discusion })

# --- temblores de ventana ---
$script:temblores = New-Object System.Collections.ArrayList
$shkTimer = New-Object System.Windows.Forms.Timer
$shkTimer.Interval = 30
$shkTimer.Add_Tick({
    for ($i = $script:temblores.Count - 1; $i -ge 0; $i--) {
        $s = $script:temblores[$i]; $s.T--
        if ($s.F.IsDisposed) { $script:temblores.RemoveAt($i); continue }
        if ($s.T -le 0) { $s.F.Location = $s.Base; $script:temblores.RemoveAt($i) }
        else { $a = [int](4 * $script:K); $s.F.Location = New-Object System.Drawing.Point(($s.Base.X + $Rnd.Next(-$a, $a + 1)), ($s.Base.Y + $Rnd.Next(-$a, $a + 1))) }
    }
    if ($script:temblores.Count -eq 0) { $shkTimer.Stop() }
})
function Sacudir($f, $ticks) {
    if ($script:aj.Epilepsia) { return }   # modo seguro: nada tiembla
    if (-not $f -or $f.IsDisposed -or $script:glitching -or $script:drag) { return }
    foreach ($s in $script:temblores) { if ($s.F -eq $f) { $s.T = [Math]::Max($s.T, $ticks); return } }
    [void]$script:temblores.Add(@{ F = $f; Base = $f.Location; T = $ticks }); $shkTimer.Start()
}
$script:humoF = $null
$humo2Timer = New-Object System.Windows.Forms.Timer
$humo2Timer.Interval = 1600
$humo2Timer.Add_Tick({ $humo2Timer.Stop(); if ($script:humoF -and -not $script:humoF.IsDisposed) { $script:humoF.Opacity = $(if ($script:humoF -eq $form) { (Opacidad-Base) } else { 0.99 }); $script:humoF.Invalidate($true) } })
function Humo($f) { if (-not $f) { return }; $f.Opacity = 0.3; $script:humoF = $f; $humo2Timer.Stop(); $humo2Timer.Start() }

# --- ventanita del invitado ---
function Colocar-Invitado {
    $f = $script:inv; if (-not $f -or $f.IsDisposed) { return }
    $b = $form.Bounds; $e = 1 - [Math]::Pow(1 - [Math]::Min(1.0, $script:invAnim / 10.0), 3)
    $off = (1 - $e) * 40 * $script:K
    $x = if ($script:invLado -gt 0) { $b.Right + 8 * $script:K - $off } else { $b.Left - $f.Width - 8 * $script:K + $off }
    $f.Location = New-Object System.Drawing.Point([int]$x, [int]($b.Top + 30 * $script:K))
    $f.Opacity = [Math]::Min(0.99, [Math]::Max(0.0, $e))
    $f.Invalidate($true)
}

function Abrir-Invitado($nombre) {
    $gk = $Skins[$nombre]; $script:invSkin = $gk; $script:invNombre = $nombre
    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = 'None'; $f.ShowInTaskbar = $false; $f.StartPosition = 'Manual'; $f.Text = 'invitado'
    $f.Size = New-Object System.Drawing.Size(220, 214); $f.BackColor = $gk.Fondo; $f.Opacity = 0
    Doble-Buffer $f
    $script:invPb = $null
    if ($gk.Gif -and $script:dImg) {
        $p = New-Object System.Windows.Forms.PictureBox
        $p.Location = New-Object System.Drawing.Point(10, 36); $p.Size = New-Object System.Drawing.Size(200, 108)
        $p.SizeMode = 'Zoom'; $p.Image = $script:dImg
        $p.BackColor = if ($gk.PbFondo) { $gk.PbFondo } else { [System.Drawing.Color]::Transparent }
        $f.Controls.Add($p); $script:invPb = $p
    }
    $l = New-Object System.Windows.Forms.Label
    $l.Location = New-Object System.Drawing.Point(10, 150); $l.Size = New-Object System.Drawing.Size(200, 56)
    $l.BackColor = if ($gk.BurFondo) { $gk.BurFondo } elseif ($gk.InvFondo) { $gk.InvFondo } else { [System.Drawing.Color]::Black }
    if ($script:fuentesPriv.ContainsKey([string]$gk.BurFuente)) { $l.UseCompatibleTextRendering = $true }
    $l.ForeColor = if ($gk.BurTexto) { $gk.BurTexto } else { $gk.StatusColor }
    $fb = if ($gk.BurFuente) { $gk.BurFuente } else { 'Consolas' }
    $l.Font = Fnt($fb, $(if ($fb -eq 'Segoe Print') { 7.5 } else { 8.5 }), [System.Drawing.FontStyle]::Bold)
    $l.BorderStyle = 'FixedSingle'; $l.Padding = New-Object System.Windows.Forms.Padding(3)
    $f.Controls.Add($l); $script:invLbl = $l
    $f.Add_Paint({ Pintar-Invitado $_.Graphics })
    Escalar $f
    $f.Owner = $form
    $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $script:invLado = if ($form.Right + $f.Width + 12 -le $wa.Right) { 1 } else { -1 }
    $script:invTamBase = $null
    $script:inv = $f; $script:invAnim = 0; $script:invSale = $false; $script:invFx = 14; $script:invTexto = ''; $script:invPos = 0
    Colocar-Invitado
    $f.Show()
    # cada invitado llega con su propio sonido
    switch ($gk.Estilo) {
        'oeste' { Sonido-De $nombre 'bang' }
        'mew' { Sonido-De $nombre 'golpe' }
        'mlg' { Sonido-De $nombre 'apuntar' }
        'culto' { Sonido-De $nombre 'balido' }
        'kaiju' { Sonido-De $nombre 'pisoton' }
        'zorro' { Sonido-De $nombre 'yip' }
        'teto' { Sonido-De $nombre 'hi' }
        'enfosi' { Sonido-De $nombre 'ding' }
        'femta' { Sonido-De $nombre 'golpe' }
        'pop' { Sonido-De $nombre 'ping' }
        'pizza' { Sonido-De $nombre 'nam' }
        'punk' { Sonido-De $nombre 'acorde' }
        'gran' { }   # llega en silencio: su único sonido es su canción
        'abismo' { Sonido-De $nombre 'brillo' }
        'evil' { Sonido-De $nombre 'medio' }
        'niebla' { Sonido-De $nombre 'brillo' }
        'pressure' { Sonido-De $nombre 'rejilla' }
        'dod' { Sonido-De $nombre 'acecho' }
        'hacker' { try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Hand.Play() } } catch {} }
        default { try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Asterisk.Play() } } catch {} }
    }
    $invTimer.Start()
}

function Pintar-Invitado($g) {
    $g.ScaleTransform($script:K, $script:K); $g.SmoothingMode = 'AntiAlias'
    $gk = $script:invSkin; $W = 220; $H = 214; $fx = $script:invFx
    if (-not $gk) { return }
    $g.Clear($gk.Fondo)
    # fondo y cabecera con el estilo del invitado
    $cab = $gk.Fondo
    switch ($gk.Estilo) {
        'hacker' { $p = New-Object System.Drawing.Pen((C 30 0 0), 1); for ($y = 30; $y -lt $H; $y += 4) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 0 0 0) }
        'web' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, 31)), $gk.Barra1, $gk.Barra2, 90); $g.FillRectangle($br, 0, 0, $W, 31); $cab = $null }
        'tele' { $lun = New-Object System.Drawing.SolidBrush((C 255 95 70)); for ($y = 36; $y -lt $H; $y += 18) { for ($x = 4; $x -lt $W; $x += 18) { $g.FillEllipse($lun, $x, $y, 5, 5) } }; $cab = (C 58 44 190) }
        'mew' { for ($x = 0; $x -lt $W; $x += 20) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 62 44 52))), $x, 30, 10, $H) }; $cab = (C 28 21 24) }
        'lobo' { $cab = (C 18 23 30) }
        'mlg' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (C 57 72 191), (C 229 45 45), 35); $g.FillRectangle($br, 0, 0, $W, $H); $cab = (C 14 14 28) }
        'oeste' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 238 128 62), (C 250 214 150), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 90 52 28) }
        'gunsaw' { $p = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(16, 255, 255, 255), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 18 9 22) }
        'culto' { $p = New-Object System.Drawing.Pen((C 110 24 34), 2); $g.DrawEllipse($p, 40, 30, 140, 140); $g.DrawEllipse($p, 50, 40, 120, 120); $cab = (C 14 8 10) }
        'kaiju' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 40 18 60), (C 220 96 52), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 12 8 10) }
        'pressure' { $p = New-Object System.Drawing.Pen((C 30 60 66), 1); for ($y = 34; $y -lt $H; $y += 6) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 8 10 14) }
        'dod' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 4 16 10), (C 10 40 26), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 4 8 6) }
        'zorro' { $pu = New-Object System.Drawing.SolidBrush((C 250 222 190)); for ($y = 40; $y -lt $H; $y += 18) { for ($x = (($y / 18) % 2) * 9 + 4; $x -lt $W; $x += 18) { $g.FillEllipse($pu, $x, $y, 5, 5) } }; $cab = (C 230 128 56) }
        'femta' { $rn = New-Object System.Random 5; for ($i = 0; $i -lt 30; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $rn.Next(30, 90) 230 20 40))), 0, $rn.Next(30, $H), $W, $rn.Next(1, 3)) }; $cab = (C 0 0 0) }
        'pop' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 40 14 80), (C 150 40 120), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $p = New-Object System.Drawing.Pen((ARGB 30 0 0 0), 1); for ($y = 30; $y -lt $H; $y += 3) { $g.DrawLine($p, 0, $y, $W, $y) }; $cab = (C 40 12 70) }
        'gran' { $rosa = New-Object System.Drawing.SolidBrush((ARGB 60 255 70 170)); for ($x = -$H; $x -lt $W; $x += 30) { $g.FillPolygon($rosa, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, $H)), (New-Object System.Drawing.PointF([float]($x + 12), $H)), (New-Object System.Drawing.PointF([float]($x + 12 + $H), 30)), (New-Object System.Drawing.PointF([float]($x + $H), 30)))) }; $rosa.Dispose(); $cab = (C 0 0 0) }
        'evil' { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 30 6 10))), 0, 30, $W, ($H - 30)); $cab = (C 0 0 0) }
        'niebla' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 74 28 124), (C 30 10 56), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 90 30 140) }
        'abismo' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 40 70 44), (C 18 34 22), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 78 56 40) }
        'enfosi' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 120 180 240), (C 200 230 255), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $cab = (C 252 200 55) }
        'teto' { $ray = New-Object System.Drawing.Pen((C 252 232 236), 8); for ($x = -$H; $x -lt $W; $x += 26) { $g.DrawLine($ray, $x, 32, ($x + $H), ($H + 32)) }; $ray.Dispose(); $cab = (C 214 40 64) }
        'pizza' { $roja = New-Object System.Drawing.SolidBrush((ARGB 90 220 40 40)); for ($x = 0; $x -lt $W; $x += 28) { $g.FillRectangle($roja, $x, 30, 14, $H) }; for ($y = 30; $y -lt $H; $y += 28) { $g.FillRectangle($roja, 0, $y, $W, 14) }; $roja.Dispose(); $cab = (C 70 200 40) }
        'punk' { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 30, $W, ($H - 30))), (C 252 206 160), (C 244 150 110), 90); $g.FillRectangle($br, 0, 30, $W, ($H - 30)); $br.Dispose(); $cab = (C 96 74 68) }
    }
    if ($cab) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($cab)), 0, 0, $W, 30) }
    $acento = if ($gk.Acento) { $gk.Acento } else { $gk.Borde }
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($acento)), 0, 30, $W, 2)
    $nom = if ($gk.Titulo) { $gk.Titulo } else { $script:invNombre }
    $est = if ($gk.FuenteTitulo -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
    $g.DrawString($nom, (FntP($gk.FuenteTitulo, 12, $est)), (New-Object System.Drawing.SolidBrush($gk.TituloColor)), 8, 4)
    $g.DrawString('INVITADO', (FntP('Consolas', 7, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 200, 200, 200))), ($W - 62), 10)
    if (-not $script:invPb) {
        # c00lgui no tiene retrato: su nombre glitcheado
        $dx = if ($fx -gt 0) { $Rnd.Next(-6, 7) } else { 0 }
        $g.DrawString('c00lgui', (FntP('Arial Black', 26)), (New-Object System.Drawing.SolidBrush((C 90 0 0))), (24 + $dx + 3), 66)
        $g.DrawString('c00lgui', (FntP('Arial Black', 26)), [System.Drawing.Brushes]::Red, (24 + $dx), 63)
    }
    # efecto de entrada de cada invitado
    if ($fx -gt 0) {
        switch ($gk.Estilo) {
            'hacker' { for ($i = 0; $i -lt 4; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush(@((C 255 0 0), (C 255 255 255), (C 0 255 255))[$Rnd.Next(3)])), $Rnd.Next(-40, $W), $Rnd.Next(0, $H), $Rnd.Next(40, 200), $Rnd.Next(1, 5)) } }
            'tele' { $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int]($H / 2 - $fx * 6), $W, [int]($fx * 12)) }
            'mlg' { Dibujar-Hit $g ($W / 2) 90 ([Math]::Max(10, $fx * 3)); $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 18), 255, 255, 255))), 0, 0, $W, $H) }
            'oeste' { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 140 110 70))), ($W - 52), 52, 22, 22); $g.FillEllipse([System.Drawing.Brushes]::Black, ($W - 46), 58, 10, 10) }
            'gunsaw' { $y = (14 - $fx) * 16; $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 255, 255, 255))), 0, $y, $W, 10) }
            'mew' { $z = New-Object System.Drawing.Pen((C 200 40 35), 5); $z.StartCap = 'Round'; $z.EndCap = 'Round'; for ($i = 0; $i -lt 3; $i++) { $g.DrawLine($z, (40 + $i * 40), 40, (90 + $i * 40), 150) } }
            'web' { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 130 200))), 0, 32, [int]($W * (14 - $fx) / 14), 4) }
            'lobo' { if ($fx % 4 -lt 2) { $am = New-Object System.Drawing.Pen((C 255 170 40), 3); $g.DrawRectangle($am, 6, 34, ($W - 12), 112) } }
            'culto' { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 18), 200, 20, 30))), ($W / 2 - 30), (90 - $fx * 2), 60, ($fx * 4)) }
            'kaiju' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 16), 255, 160, 40))), 0, 0, $W, $H) }
            'pressure' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 16), 70, 190, 200))), 0, 0, $W, $H) }
            'dod' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $fx * 16), 200, 0, 0))), 0, 0, $W, $H) }
            'zorro' { for ($i = 0; $i -lt 3; $i++) { Dibujar-Corazon $g (50 + $i * 60) (150 - (14 - $fx) * 8) 10 ([Math]::Min(255, $fx * 18)) } }
            'femta' { for ($i = 0; $i -lt 4; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush(@((C 230 20 40), (C 255 255 255), (C 40 230 255))[$Rnd.Next(3)])), $Rnd.Next(-40, $W), $Rnd.Next(0, $H), $Rnd.Next(40, 200), $Rnd.Next(2, 6)) } }
            'pop' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 90, 230, 250))), 0, [int]((14 - $fx) * 15), $W, 10) }
            'gran' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 32, 208, 44))), 0, 0, $W, $H) }
            'evil' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 150, 0, 10))), 0, 0, $W, $H) }
            'niebla' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(180, $fx * 12), 255, 186, 244))), 0, 0, $W, $H) }
            'abismo' { $p = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([Math]::Min(220, $fx * 16), 210, 255, 220), 2); for ($i = 0; $i -lt 6; $i++) { $xx = 20 + $i * 36; $g.DrawLine($p, $xx, ($H - (14 - $fx) * 14), ($xx + 6), ($H - (14 - $fx) * 14 - 40)) }; $p.Dispose() }
            'enfosi' { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $fx * 14), 255, 214, 60))), 0, 0, $W, $H) }
            'teto' { for ($i = 0; $i -lt 3; $i++) { Texto-Contorno $g '♪' 'Segoe UI Symbol' 20 (40 + $i * 60) (130 - (14 - $fx) * 7) (@((C 214 40 64), (C 246 170 30), (C 255 255 255))[$i]) 3 ([Math]::Min(255, $fx * 18)) } }
            'pizza' { for ($i = 0; $i -lt 4; $i++) { Dibujar-Trozo $g (30 + $i * 52) (40 + (14 - $fx) * 9 + ($i % 2) * 14) 20 ($fx * 25 + $i * 70) } }
            'punk' { for ($i = 0; $i -lt 3; $i++) { Texto-Contorno $g (@('♪', '♫', '★')[$i]) 'Segoe UI Symbol' 22 (40 + $i * 60) (130 - (14 - $fx) * 7) (@((C 255 255 255), (C 255 80 160), (C 255 255 255))[$i]) 3 ([Math]::Min(255, $fx * 18)) } }
        }
    }
    $g.DrawRectangle((New-Object System.Drawing.Pen($acento, 3)), 1, 1, ($W - 3), ($H - 3))
}

$invTimer = New-Object System.Windows.Forms.Timer
$invTimer.Interval = 30
$invTimer.Add_Tick({
    Sin-Destellos
    $f = $script:inv
    if (-not $f -or $f.IsDisposed) { $invTimer.Stop(); return }
    if ($script:invSale) {
        $script:invAnim -= 1; Colocar-Invitado
        if ($script:invAnim -le 0) { Cerrar-Invitado }
        return
    }
    if ($script:invAnim -lt 10) { $script:invAnim++; Colocar-Invitado }
    if ($script:invPos -lt $script:invTexto.Length) { $script:invPos++; $script:invLbl.Text = $script:invTexto.Substring(0, $script:invPos) }
    if ($script:invEst -gt 0 -and $script:invPb) {
        $script:invEst--
        if (-not $script:invRuido) { $script:invRuido = Nuevo-Ruido 64 40 }
        if ($script:invEst -gt 0) { Llenar-Ruido $script:invRuido; $script:invPb.Image = $script:invRuido; $script:invPb.Invalidate() } else { $script:invPb.Image = $script:dImg }
    }
    if ($script:invFx -gt 0) { $script:invFx--; $f.Invalidate() }
})

function Cerrar-Invitado {
    $invTimer.Stop()
    if ($script:inv -and -not $script:inv.IsDisposed) { if ($script:invPb) { $script:invPb.Image = $null }; $script:inv.Close(); $script:inv.Dispose() }
    $script:inv = $null; $script:invPb = $null; $script:invLbl = $null; $script:invSkin = $null
    if ($script:dImg) { $script:dImg.Dispose(); $script:dImg = $null }
    if ($script:invRuido) { $script:invRuido.Dispose(); $script:invRuido = $null }
}

# efectos según lo que se dice en la discusión
function Efectos-Linea($quien, $txt) {
    if ($quien -eq 'Nanachi' -and $txt -match 'Nnaa') { Sonido-De 'Nanachi' 'brillo' }
    if ($txt -match '[Ee]stofado') { Sonido-De 'Nanachi' 'burbujas' }
    if ($txt -match 'STALL') { Sonido-De 'Evil Scary' 'stall' }
    elseif ($txt -match 'EVIL AND SCARY') { Sonido-De 'Evil Scary' 'susto' }
    if ($txt -match 'FSSS|niebla rosa') { Sonido-De 'Soft Fuzzy Man' 'puff' }
    $esInv = $quien -ne $script:skinNombre
    $f = if ($esInv) { $script:inv } else { $form }
    if ($txt -match 'BANG') { Sonido-De 'Zodiac' 'bang'; Sacudir $form 10; Sacudir $script:inv 10; if ($esInv) { $script:invFx = 8 } }
    elseif ($txt -match 'Smokebomb') { Sonido-De 'Mikaela' 'humo'; Humo $f }
    elseif ($txt -match "DON'T TOUCH|NO TOQUES|motosierra") { Sonido-De 'Kevin' $(if ($txt -match 'motosierra') { 'grito' } else { 'grr' }); Sacudir $f 9 }
    elseif ($quien -eq 'Kevin' -and $txt -match 'ÑAM') { Sonido-De 'Kevin' 'nam' }
    elseif ($txt -match 'KABOOM|EXPLOTA|explota') { Sonido-De 'Kennyoung' 'kaboom'; Sacudir $form 12; Sacudir $script:inv 12 }
    elseif ($txt -match 'ENCORE|público') { Sonido-De 'Kennyoung' 'publico' }
    elseif ($txt -match 'Rasguea|acorde|guitarra') { Sonido-De 'Kennyoung' 'acorde' }
    elseif ($txt -match 'ÑAM|CHOMP|[Ee]ructa|[Tt]raga') { Sonido-De 'Guillotina' 'comer'; Sacudir $f 6 }
    elseif ($txt -match 'Bzz') { if ($esInv) { $script:invEst = 12 } else { Corte-Senal 8 } }
    elseif ($txt -match 'GRRRRRAAAARRRGH|AAARGH') { Sonido-De 'Pyrophina y Zaratana' 'pruge'; Sacudir $form 8; Sacudir $script:inv 8 }
    elseif ($txt -match 'GRRRR, GRRRRR|Grrrr, burp') { Sonido-De 'Pyrophina y Zaratana' 'zruge'; Sacudir $f 6 }
    elseif ($txt -match 'AAAAAAAAH|GRITA') { Sonido-De 'Cordero y Cabra' 'grito'; Sacudir $f 8 }
    elseif ($txt -match 'Beee') { Sonido-De 'Cordero y Cabra' 'balido' }
    elseif ($txt -match 'NO TE MUEVAS|GRRGH|FURIOSA|denegada') { Sacudir $f 8 }
    if ($quien -eq 'Averi' -and $Rnd.Next(2) -eq 0) { Sonido-De 'Averi' 'yip' }
    if ($quien -eq 'Kasane Teto') { Voz-Teto $txt }
    if ($quien -eq 'Pursuer') { if ($txt -match 'CARNE|AÚLLA') { Sonido-De 'Pursuer' 'aullido'; Sacudir $f 10 } elseif ($txt -match 'te veo|Desaparece') { Sonido-De 'Pursuer' 'acecho' } }
    if ($quien -eq 'Mikaela' -and $txt -match 'mira') { Sonido-De 'Mikaela' 'apuntar' }
    if ($quien -eq 'Guillotina' -and $txt -match 'boca') { Sonido-De 'Guillotina' 'golpe' }
    if ($quien -eq 'Static Miku' -and $esInv) { $script:invFx = 6 }
    if ($quien -eq 'c00lgui' -and $esInv) { $script:invFx = 8 }
    # Kevin en su Paint pone cara según lo que dice
    if ($quien -eq 'Kevin' -and -not $esInv) {
        if ($txt -match 'motosierra') { Actor-Pose 'V' 'motosierra' 1800 }
        elseif ($txt -match 'MUERDO|BITE|muerde') { Actor-Pose 'V' 'muerde' 2400 }
        elseif ($txt -match "DON'T TOUCH|NO TOQUES|cuchillo") { Actor-Pose 'V' 'arma' 2200 }
        elseif ($txt -match 'mermelada|jelly') { Actor-Pose 'V' 'mermelada' 2400 }
        elseif ($txt -match 'queso azul|huele') { Actor-Pose 'V' 'sudor' 2200 }
        elseif ($txt -match 'baila|canta|♪') { Actor-Pose 'V' 'baile' 3000 }
    }
}

# la frase del invitado siempre cabe: si es larga, la letra se hace un poco más pequeña
function Encajar-Invitado($txt) {
    $l = $script:invLbl; if (-not $l) { return }
    if (-not $script:invTamBase) { $script:invTamBase = $l.Font.Size }
    $fam = $l.Font.FontFamily; $st = $l.Font.Style; $tam = $script:invTamBase
    while ($tam -gt 6) {
        $fn = New-Object System.Drawing.Font($fam, [float]$tam, $st, [System.Drawing.GraphicsUnit]::Pixel)
        $h = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $fn, (New-Object System.Drawing.Size(($l.ClientSize.Width - $l.Padding.Horizontal), 100000)), [System.Windows.Forms.TextFormatFlags]::WordBreak).Height
        if ($h -le ($l.ClientSize.Height - $l.Padding.Vertical)) { break }
        $fn.Dispose(); $tam -= 1
    }
    $l.Font = New-Object System.Drawing.Font($fam, [float]$tam, $st, [System.Drawing.GraphicsUnit]::Pixel)
}
function Iniciar-Discusion {
    if (-not $script:aj.Invitados) { return }
    if ($script:discutiendo -or (Ocupado) -or $form.WindowState -eq 'Minimized') { return }
    # la ventanita de la anterior todavía se está yendo, o acaba de terminar
    if ($script:inv -or ([Environment]::TickCount - $script:dFin) -lt 2500) { return }
    if ([Environment]::TickCount -lt $script:twBloqueo) { return }
    $yo = $script:skinNombre
    $cands = @($Discusiones | Where-Object { @($_ | ForEach-Object { $_[0] }) -contains $yo })
    if ($cands.Count -eq 0) { return }
    # no repetir la misma conversación dos veces seguidas
    if ($cands.Count -gt 1) { $cands = @($cands | Where-Object { -not [object]::ReferenceEquals($_, $script:dUltima) }) }
    $script:dLineas = $cands[$Rnd.Next($cands.Count)]; $script:dUltima = $script:dLineas
    $invitado = @($script:dLineas | ForEach-Object { $_[0] } | Where-Object { $_ -ne $yo })[0]
    $script:dImg = Cargar-Img $Skins[$invitado].Gif
    $script:dIdx = 0; $script:discutiendo = $true
    Abrir-Invitado $invitado
    $dTimer.Interval = 450; $dTimer.Start()
}

function Paso-Discusion {
    $dTimer.Stop()
    if (-not $script:discutiendo) { return }
    if ($script:dIdx -ge $script:dLineas.Count) { Fin-Discusion; return }
    $l = $script:dLineas[$script:dIdx]; $script:dIdx++
    $quien = $l[0]; $txt = $l[1]
    if ($quien -ne $script:skinNombre) {
        # habla el invitado, en su ventanita
        $script:invTexto = $txt; $script:invPos = 0; Encajar-Invitado $txt
        switch ($script:skin.Estilo) {
            'lobo' { $script:caraModo = 'serio' }
            'zorro' { $script:caraModo = 'abiertos' }
            'culto' { if ($Rnd.Next(2) -eq 0) { Cara2 'risa' 1600 } }
            'pizza' { if ($Rnd.Next(2) -eq 0) { Cara (Azar @('piensa', 'chulo', 'sudor')) 1800 } }
            { $_ -in @('mew', 'mlg', 'tele', 'oeste') } { if ($Rnd.Next(2) -eq 0) { Cara 'clic' 1600 } }
        }
    } else {
        if ($script:skin.Estilo -eq 'hacker') { Glitch 3 "> $txt" } else { Decir-Fijo $txt 'abiertos' 0 }
    }
    Efectos-Linea $quien $txt
    $dTimer.Interval = [Math]::Max(2400, 1500 + $txt.Length * 55)
    $dTimer.Start()
}

function Fin-Discusion($rapido = $false) {
    $dTimer.Stop()
    $eraDiscusion = $script:discutiendo
    $script:discutiendo = $false; $script:dInvitadoHabla = $false; $script:dFin = [Environment]::TickCount
    if ($rapido) { Cerrar-Invitado; return }
    if ($script:inv) { $script:invSale = $true; $invTimer.Start() }
    # a veces el anfitrión remata con su opinión del invitado
    if ($eraDiscusion -and $script:invNombre -and $Rnd.Next(2) -eq 0) { Decir (Opinion $script:invNombre) 'abiertos' }
}

# frases cuando no haces nada
$idleTimer = New-Object System.Windows.Forms.Timer
$idleTimer.Interval = 18000
$idleTimer.Add_Tick({
    if ((Ocupado) -or $script:modoSkins -or $script:discutiendo) { return }
    $k = $script:skin; $r = $Rnd.Next(100)
    if ($r -lt 20) { Decir (Opinion-Azar) 'abiertos'; return }   # opina de otra skin
    if ($r -lt 38) { Iniciar-Discusion; return }                 # discute con otro asistente
    switch ($k.Estilo) {
        'hacker' { if ($r -lt 50) { Glitch 6 (Azar $k.Idle) } else { Decir (Azar $k.Idle) } }
        'tele' {
            if ($r -lt 32 -and $script:imgs.raro) { Cara 'raro' 3500; Decir (Azar $k.Raro) }
            elseif ($r -lt 55) { Corte-Senal 8; Decir (Azar $k.Idle) }
            else { Decir (Azar $k.Idle) }
        }
        'mew' {
            if ($r -lt 50 -and $script:gVivo) { Guillotina-Ataque (Azar @('lanza', 'digiere', 'come')) (Azar $k.Idle) }
            elseif ($r -lt 62 -and $script:gVivo -and $script:gFase2) { Guillotina-Ataque 'barriga' '*Se golpea la barriga. Tiembla todo el callejón.*' }
            else { Decir (Azar $k.Idle) }
        }
        'mlg' {
            if ($r -lt 40) { Sonido 'humo'; $form.Opacity = 0.35; $humoTimer.Start(); Decir '*Smokebomb.* Ahora no me ves.' }
            elseif ($r -lt 52) { Cara 'clic' 2500; Decir '¡¿Un Terminator?! ...falsa alarma.' }
            else { Decir (Azar $k.Idle) }
        }
        'gunsaw' {
            if ($k.Telarana -and $r -lt 50 -and -not $script:telarana) { $presa = Velvet-Escupir; if ($presa) { Decir "*Escupe una telaraña sobre $presa.* Uy. Se me escapó, cielo." } }
            elseif ($k.Hambre -and $r -lt 50) { Decir 'BLUB. BLUB. *Dune hace burbujas.*' }
            else { Decir (Azar $k.Idle) }
        }
        'oeste' {
            if ($r -lt 40 -and $script:balas -gt 0) { [void](Zodiac-Disparo); Decir '¡Algo se ha movido! *BANG* ...era una mosca.' }
            elseif ($r -lt 52) { Cara 'pose' 3000; Decir '*Posa para nadie en concreto.*' }
            else { Decir (Azar $k.Idle) }
        }
        'culto' {
            if ($r -lt 55) { Sonido 'balido'; Cara 'clic' 1800; Decir (Azar $k.Idle) }
            elseif ($r -lt 65) { Sonido 'risa'; Cara2 'risa' 2600; Decir 'Cabra: *Se ríe sola mirando al Cordero.* Nada, nada.' }
            else { Decir (Azar $k.Idle) }
        }
        'kaiju' {
            if ($r -lt 70) { Kaiju-Ataque (@('P', 'Z')[$Rnd.Next(2)]) }
            elseif ($r -lt 80) { if ($Rnd.Next(2) -eq 0) { Sonido 'pruge'; Decir 'Pyrophina: ¡GRRRRRAAAARRRGH!' } else { Sonido 'zruge'; Decir 'Zaratana: ¡GRRRR, GRRRRR!' } }
            else { Decir (Azar $k.Idle) }
        }
        'pressure' {
            if ($r -lt 52 -and -not $script:modoTienda) { Decir (Azar $k.Respiradero) }
            elseif ($r -lt 60) { Decir 'Ese parecía un poco distinto de lo normal. Hmm. Me pregunto qué le pasa.' }
            else { Decir (Azar $k.Idle) }
        }
        'dod' {
            if ($r -lt 52) { Pursuer-Acecho }
            elseif ($r -lt 62) { Pursuer-Ataque 'aullido' }
            else { Decir (Azar $k.Idle) }
        }
        'femta' {
            if ($r -lt 25) { Token-Palabra; Sonido 'glitch'; Decir (Azar $k.Idle) }
            elseif ($r -lt 35) { Sonido 'golpe'; $a = $script:actores['K']; if ($a) { $a.Temblor = 8 }; Decir '*Le pega un cabezazo al altavoz. Suena más fuerte.* Mejor.' }
            else { Decir (Azar $k.Idle) }
        }
        'pop' {
            if ($r -lt 30 -and -not $script:popDND) { [void](Tetra-Mensaje); Decir (Azar @('*Le llega un mensaje. Lo mira. Lo deja en visto.* Luego contesto.', '*Mira el móvil.* Es neems. ...le contesto mañana.', '*Ping.* Uy. Un mensaje. Qué miedo dan los mensajes.')) }
            elseif ($r -lt 45) { Sonido 'disco'; $a = $script:actores['E']; if ($a) { $a.Salto = 12 }; Decir '*Baila un poco de disco sin levantarse mucho del sitio.*' }
            else { Decir (Azar $k.Idle) }
        }
        'enfosi' {
            if ($script:ef -and -not $script:ef.W -and -not $script:ef.Cartel -and $r -lt 40) { Enfosi-Llega }
            elseif (-not $script:ef -or -not $script:ef.W) { Decir (Azar $k.Idle) }
        }
        'teto' {
            if ($r -lt 18) { Teto-Pajaro; Decir '¡Mira, un pajarito! ...¿de dónde salen todos?' }
            elseif ($r -lt 32) { Sonido (Azar @('hi', 'hehe', 'huh')); $script:tetoVozT = [Environment]::TickCount; Decir (Azar $k.Idle) }
            elseif ($r -lt 50) {
                Sonido 'canta'; $script:tetoVozT = [Environment]::TickCount
                $a = $script:actores['T']; if ($a) { $a.Salto = 12 }
                foreach ($i in 0..3) { Flotante (Azar @('♪', '♫')) (480 + $i * 34) (80 + $Rnd.Next(60)) (@((C 214 40 64), (C 246 170 30), (C 255 255 255), (C 214 40 64))[$i]) 22 'Segoe UI Symbol' }
                Decir (Azar @('♪ La la la~ ♪ *Canta sola en medio del escritorio.*', '♪ Lu lu lu~ ♪ Me la acabo de inventar. ¡Ya se me ha olvidado!', '♪ Na na na~ ♪ *Baila y canta a la vez. Casi se cae.*', '♪ Du du du~ ♪ ¿Te gusta? ¡Es mi nuevo single!'))
            }
            else { Decir (Azar $k.Idle) }
        }
        'gran' {
            if ($r -lt 55) { Gran-Tapar 6000; Decir (Azar $k.Idle) }
            else { Decir (Azar $k.Idle) }
        }
        'evil' {
            if ($r -lt 40) { Decir (Azar $k.Idle) }
            elseif ($r -lt 55) { Es-Reset; Es-Rebote 3.0; Decir '*Bota sin avisar.* ...el sonido ha sido más agudo esta vez.' }
            else { Decir (Azar $k.Idle) }
        }
        'niebla' {
            if ($r -lt 30) { Actor-Pose 'F' 'brazos' 2200; Decir (Azar $k.Idle) }
            elseif ($r -lt 42) { Sonido 'puff'; Sf-Niebla 1500 90; Decir '*Suelta una nubecita rosa.* Perdona. Es que me emociono.' }
            else { Decir (Azar $k.Idle) }
        }
        'abismo' {
            if ($r -lt 30) { Nn-Cara 'sentado' 6000; Decir (Azar $k.Idle) }
            elseif ($r -lt 42) { Sonido 'burbujas'; Nn-Reset; $script:nn.Vapor = 40; Nn-Cara 'mastica' 3000; Decir (Azar @('*Remueve la olla.* Glup. Glup. Eso es buena señal. Creo.', '*Prueba el estofado con una cuchara larga.* ...le falta algo. Le faltan muchas cosas.', 'Si oyes burbujas, es el estofado. Si oyes otra cosa, no es el estofado. Corre.')) }
            elseif ($r -lt 52) { Nn-Cara 'triste' 5000; Decir (Azar @('*Mira el muñeco de pájaro un buen rato.* ...lo cosí yo. Para alguien que quería mucho.', 'Mitty decía que todo vuelve al Abismo. Yo no me lo creo del todo. Pero me gusta pensarlo.', 'Algún día cocinaré algo rico de verdad. Por si nos volvemos a ver. Nnaa.')) }
            elseif ($r -lt 62) { Nn-Cara 'risa' 4000; Decir (Azar @('*Se ríe sola de algo.* Me he acordado de Reg cuando probó mi estofado. Puso una cara...', 'Riko se quedó dormida encima de un libro de setas. Igual que yo. Somos unos sabios.')) }
            elseif ($r -lt 70) { Nn-Cara 'nnaa' 2000; Sonido 'silbato'; Decir (Azar @('¿Has oído eso? Un silbato. Hay exploradores cerca. Me escondo. *No se esconde.*', '¡Nnaa! *Da un respingo.* ...era una seta cayéndose. Nada.')) }
            else { Decir (Azar $k.Idle) }
        }
        'punk' {
            if ($r -lt 50) { Ky-Video 'loner' 6000; Decir (Azar @('*Se pone con el portátil.* Estoy componiendo. O viendo vídeos. Lo segundo.', '*Se tapa con la manta delante del portátil.* Modo loner activado.', 'Estoy editando el próximo vídeo. Va a salir... algún día.')) }
            elseif ($r -lt 60) { Ky-Video 'online' 5000; Decir (Azar @('*Mira el portátil.* La gente de internet... a veces son mejores amigos que los de verdad.', 'People online... *tararea.* Esa es mía, por cierto.')) }
            elseif ($r -lt 70) { Ky-Video 'nada' 7000; Decir (Azar @('*Sale al balcón a ver el atardecer.* Esto pide una canción.', '*Se sienta en la barandilla.* No hago nada. Y me sale genial.')) }
            elseif ($r -lt 78) { Ky-Video 'piensa' 6000; Decir (Azar @('*Piensa en algo.* ...se me ha olvidado qué pensaba. Era una melodía. Creo.', '*Mira al infinito.* ¿Y si la próxima canción va sobre... nada? Ya tengo una que se llama así.')) }
            elseif ($r -lt 84) { Ky-Video 'triste' 5000; Decir '*Se pone la capucha y toca algo lento.* A veces también toca canción triste.' }
            elseif ($r -lt 88) { Ky-Video 'calavera' 5000; Decir '*Aparece disfrazado de esqueleto.* ¿Qué? Siempre es Halloween en el pop-punk.' }
            else { Decir (Azar $k.Idle) }
        }
        'pizza' {
            if ($r -lt 52 -and -not $script:pzQueso -and $script:pzFx -le 0) { if (-not (Kevin-Queso)) { Decir (Azar $k.Idle) } }
            elseif ($r -lt 62) { Actor-Pose 'V' 'mermelada' 2700; Decir (Azar @('*Saca un bote de mermelada.* Esta tampoco se toca. Ni la pizza ni la mermelada.', '*Abraza su mermelada.* Don''t touch my jelly. Es la regla número tres.', 'Mermelada de fresa. Mía. Como todo lo que está en este Paint.')) }
            elseif ($r -lt 70) { Actor-Pose 'V' 'piensa' 2600; Decir (Azar $k.Idle) }
            elseif ($r -lt 76) { Sonido 'baile'; Actor-Pose 'V' 'baile' 4300; Decir '*Se pone a bailar solo.* ¡Nadie me mira! ...tú me miras. Da igual.' }
            else { Decir (Azar $k.Idle) }
        }
        'zorro' {
            if ($r -lt 60 -and $script:antojo -ge 60) { Decir '¿...huele a pollo? No huele. Pero me apetece un sándwich. (haz clic en mí)' 'serio' }
            elseif ($r -lt 70) { Sonido 'yip'; Decir (Azar $k.Idle) 'abiertos' }
            else { Decir (Azar $k.Idle) (@('cerrados', 'abiertos')[$Rnd.Next(2)]) }
        }
        default { Decir (Azar $k.Idle) }
    }
})

# ================= GLITCH (c00lgui) =================
$CharsGlitch = '#@$%&!?01/\|<>{}[]~^*=+'.ToCharArray()
$ErroresGlitch = @(
    'FATAL ERROR 0x0000C00L'
    'MEMORY CORRUPTED AT 0xDEADBEEF'
    'gui.exe has stopped responding'
    'T E A M   C 0 0 L K I D D'
    'ERR: reality.dll not found'
    '!!!! SYSTEM COMPROMISED !!!!'
    'stack overflow // stack overflow //'
)
function Revolver([string]$t) {
    $a = $t.ToCharArray()
    for ($i = 0; $i -lt $a.Length; $i++) { if ($Rnd.Next(100) -lt 40) { $a[$i] = $CharsGlitch[$Rnd.Next($CharsGlitch.Length)] } }
    return -join $a
}

$script:gTicks = 0; $script:gAccion = $null; $script:gOrig = @(); $script:gBase = $null
$gTimer = New-Object System.Windows.Forms.Timer
$gTimer.Interval = 45
$gTimer.Add_Tick({
    if ($script:gTicks -le 0) {
        $gTimer.Stop()
        foreach ($o in $script:gOrig) { $o.C.Text = $o.T }
        $form.BackColor = $script:skin.Fondo
        $form.Opacity = (Opacidad-Base)
        $form.Location = $script:gBase
        $script:glitching = $false
        $form.Invalidate()
        $acc = $script:gAccion; $script:gAccion = $null
        if ($acc -is [hashtable]) {
            $script:skinNombre = $acc.Skin; Construir-UI
            Glitch 16 (Mensaje-Entrada $acc.Prev)
        } elseif ($acc) { Decir $acc }
        return
    }
    $script:gTicks--
    $colores = @((C 0 0 0), (C 120 0 0), (C 255 0 0), (C 20 0 0), $script:skin.Fondo)
    $form.BackColor = $colores[$Rnd.Next($colores.Count)]
    $form.Opacity = 0.55 + $Rnd.NextDouble() * 0.45
    $form.Location = New-Object System.Drawing.Point(($script:gBase.X + $Rnd.Next(-9, 10)), ($script:gBase.Y + $Rnd.Next(-6, 7)))
    foreach ($o in $script:gOrig) { if ($Rnd.Next(2) -eq 0) { $o.C.Text = Revolver $o.T } else { $o.C.Text = $o.T } }
    if ($script:status) { $script:status.Text = $ErroresGlitch[$Rnd.Next($ErroresGlitch.Count)] }
    $form.Invalidate()
})

function Glitch($ticks, $accion) {
    if ($script:glitching) { return }
    $script:glitching = $true
    # modo seguro: el glitch no parpadea; se salta directamente a lo que tenía que pasar después
    $script:gTicks = $(if ($script:aj.Epilepsia) { 0 } else { $ticks }); $script:gAccion = $accion; $script:gBase = $form.Location
    $script:gOrig = @()
    $todos = @($form.Controls) + @($script:grid.Controls)
    foreach ($c in $todos) {
        if ($c -ne $script:status -and $c -ne $script:urlLbl -and $c.Text) { $script:gOrig += @{ C = $c; T = $c.Text } }
    }
    try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Hand.Play() } } catch {}
    $gTimer.Start()
}

# ================= TRANSICIÓN: CARGAR PÁGINA WEB (SeaDrive) =================
$script:wPaso = 0; $script:wProg = 0
$wTimer = New-Object System.Windows.Forms.Timer
$wTimer.Interval = 40
$wTimer.Add_Tick({
    $script:wPaso++; $p = $script:wPaso
    $url = $script:skin.Url
    $script:urlLbl.Text = $url.Substring(0, [Math]::Min($url.Length, $p * 2))
    if ($p -gt 16) {
        $paso = $Rnd.Next(0, 7)
        if ($script:wProg -gt 60 -and $script:wProg -lt 72) { $paso = $Rnd.Next(0, 2) }   # se "atasca" un poco, como las webs de verdad
        $script:wProg = [Math]::Min(100, $script:wProg + $paso)
    }
    $script:wBar.Width = [int](3 * $script:wProg * $script:K)
    $spin = '◐◓◑◒'[$p % 4]
    if ($p -le 16) { $etapa = 'Conectando con seadrive.howto...' }
    elseif ($script:wProg -lt 30) { $etapa = 'Descargando seadrive.gif (37 KB)...' }
    elseif ($script:wProg -lt 60) { $etapa = 'Cargando sarcasmo.js...' }
    elseif ($script:wProg -lt 85) { $etapa = 'Aplicando estilos.css...' }
    else { $etapa = 'Casi listo... (mentira)' }
    $script:wMsg.Text = "$spin  $etapa"
    if ($script:wProg -ge 100) {
        $script:wFin++
        if ($script:wFin -gt 6) {
            $wTimer.Stop()
            $form.Controls.Remove($script:wOv); $script:wOv.Dispose()
            $script:urlLbl.Text = $url
            $script:transicion = $false
            Decir $script:wFinal
        }
    }
})

function Transicion-Web($final) {
    $script:transicion = $true
    $W = [int]($form.ClientSize.Width / $script:K); $H = [int]($form.ClientSize.Height / $script:K)
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(3, 89)
    $ov.Size = New-Object System.Drawing.Size(($W - 6), ($H - 89 - 11))
    $ov.BackColor = [System.Drawing.Color]::White
    $ow = $ov.Width

    $t1 = New-Object System.Windows.Forms.Label
    $t1.Text = 'seadrive.howto'
    $t1.Font = Fnt('Segoe UI Light', 22)
    $t1.ForeColor = (C 40 130 200)
    $t1.TextAlign = 'MiddleCenter'
    $t1.Location = New-Object System.Drawing.Point(0, 30)
    $t1.Size = New-Object System.Drawing.Size($ow, 50)

    $script:wMsg = New-Object System.Windows.Forms.Label
    $wMsg.Font = Fnt('Segoe UI Symbol', 9)
    $wMsg.ForeColor = (C 110 110 110)
    $wMsg.TextAlign = 'MiddleCenter'
    $wMsg.Location = New-Object System.Drawing.Point(0, 90)
    $wMsg.Size = New-Object System.Drawing.Size($ow, 24)

    $barO = New-Object System.Windows.Forms.Panel
    $barO.BackColor = (C 222 230 238)
    $barO.Location = New-Object System.Drawing.Point([int](($ow - 300) / 2), 122)
    $barO.Size = New-Object System.Drawing.Size(300, 12)
    $script:wBar = New-Object System.Windows.Forms.Panel
    $wBar.BackColor = (C 40 130 200)
    $wBar.Location = New-Object System.Drawing.Point(0, 0)
    $wBar.Size = New-Object System.Drawing.Size(0, 12)
    $barO.Controls.Add($wBar)

    $pie = New-Object System.Windows.Forms.Label
    $pie.Text = '© HowTo Corp.  ·  Tu asistente favorito (no tienes otro)'
    $pie.Font = Fnt('Segoe UI', 8)
    $pie.ForeColor = (C 160 160 160)
    $pie.TextAlign = 'MiddleCenter'
    $pie.Location = New-Object System.Drawing.Point(0, ($ov.Height - 26))
    $pie.Size = New-Object System.Drawing.Size($ow, 20)

    $ov.Controls.AddRange(@($t1, $wMsg, $barO, $pie))
    Escalar $ov
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:urlLbl.Text = ''
    $script:wOv = $ov; $script:wPaso = 0; $script:wProg = 0; $script:wFin = 0; $script:wFinal = $final
    $wTimer.Start()
}

# ================= TRANSICIÓN: ESTÁTICA DE TELE (Static Miku) =================
$script:sPaso = 0
$sTimer = New-Object System.Windows.Forms.Timer
$sTimer.Interval = 45
$sTimer.Add_Tick({
    $script:sPaso++
    Llenar-Ruido $script:sRuido
    $ov = $script:sOv
    if ($script:sPaso -gt 24) {
        # la tele "se enciende" desde una línea en el centro
        $W = $ov.Width; $H = $ov.Height
        $banda = [int]($H * ($script:sPaso - 24) / 8)
        $reg = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
        $reg.Exclude((New-Object System.Drawing.Rectangle(0, [int](($H - $banda) / 2), $W, $banda)))
        $viejo = $ov.Region; $ov.Region = $reg; if ($viejo) { $viejo.Dispose() }
    }
    if ($script:sPaso -ge 33) {
        $sTimer.Stop()
        $form.Controls.Remove($ov); $ov.Dispose(); $script:sRuido.Dispose()
        $script:transicion = $false
        Decir $script:sFinal
        return
    }
    $ov.Invalidate()
})

function Transicion-Estatica($final) {
    $script:transicion = $true
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0)
    $ov.Size = $form.ClientSize
    $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $script:sRuido = Nuevo-Ruido 120 64
    $ov.Add_Paint({
        $g = $_.Graphics; $g.ScaleTransform($script:K, $script:K)
        $W = [int]($this.Width / $script:K); $H = [int]($this.Height / $script:K)
        $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
        $g.DrawImage($script:sRuido, (New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
        if ($script:sPaso % 10 -lt 7) {
            $g.DrawString('CH 03', (FntP('Consolas', 20, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Lime, ($W - 120), 12)
        }
        $g.DrawString('▶ STATIC', (FntP('Consolas', 13, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 14, ($H - 36))
        if ($script:sPaso -gt 24) {
            $banda = [int]($H * ($script:sPaso - 24) / 8)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int](($H - $banda) / 2) - 3, $W, 3)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, [int](($H + $banda) / 2), $W, 3)
        }
    })
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:sOv = $ov; $script:sPaso = 0; $script:sFinal = $final
    try { if ($script:aj.Sonido) { [System.Media.SystemSounds]::Asterisk.Play() } } catch {}
    $sTimer.Start()
}

# ================= INTROS A PANTALLA COMPLETA (Guillotina y Angela) =================
$script:iPaso = 0; $script:iTotal = 0; $script:iRecursos = @()
$iTimer = New-Object System.Windows.Forms.Timer
$iTimer.Interval = 45
$iTimer.Add_Tick({
    $script:iPaso++
    if ($script:iPaso -ge $script:iTotal) {
        $iTimer.Stop()
        $form.Controls.Remove($script:iOv); $script:iOv.Dispose()
        foreach ($r in $script:iRecursos) { if ($r) { $r.Dispose() } }
        $script:iRecursos = @()
        $script:transicion = $false
        if ($script:iDespues) { $d = $script:iDespues; $script:iDespues = $null; & $d } else { Decir $script:iFinal 'abiertos' }
        return
    }
    # si la ventana cambia de tamaño durante la intro, la intro la sigue
    if ($script:iOv.Top -eq 0 -and ($script:iOv.Width -ne $form.ClientSize.Width -or $script:iOv.Height -ne $form.ClientSize.Height)) { $script:iOv.Size = $form.ClientSize }
    if ($script:iTick) { & $script:iTick $script:iOv $script:iPaso }
    $script:iOv.Invalidate()
})

# --- logo de inicio: JOSEPABLINI CORPORATION ---
$script:iDespues = $null
# los dos van de busto (cabeza y hombros); Tung Tung Sahur un poco más alto que el panda
$AltoTung = 1.08
function Logo-Inicio {
    $script:lgImg = if (Test-Path (Ruta 'skins\logo\logo.png')) { Cargar-Img 'skins\logo\logo.png' } else { $null }
    $script:lgImg2 = if (Test-Path (Ruta 'skins\logo\tung.png')) { Cargar-Img 'skins\logo\tung.png' } else { $null }
    $script:lgImg3 = if (Test-Path (Ruta 'skins\logo\randy.png')) { Cargar-Img 'skins\logo\randy.png' } else { $null }
    $script:iRecursos = @($script:lgImg, $script:lgImg2, $script:lgImg3)
    $script:iDespues = { Efecto-Entrada $null }
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAlias'
        # aparece poco a poco y se apaga al final
        $a = if ($p -lt 20) { $p / 20.0 } elseif ($p -gt 112) { [Math]::Max(0.0, (128 - $p) / 16.0) } else { 1.0 }
        $alto = if ($script:lgImg) { $H * 0.56 } else { 0 }
        if ($script:lgImg) {
            # el panda y, a su lado, su compañero; los dos de busto y apoyados a la misma altura
            $z = 1 + $p * 0.0008
            $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$a
            $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
            $dh = $alto * $z; $dw = $script:lgImg.Width * $dh / $script:lgImg.Height
            $suelo = $H * 0.66 - 8; $th2 = [Math]::Min($dh * $AltoTung, $suelo - 6); $dh = [Math]::Min($dh, $th2 / $AltoTung); $dw = $script:lgImg.Width * $dh / $script:lgImg.Height; $tw2 = if ($script:lgImg2) { $script:lgImg2.Width * $th2 / $script:lgImg2.Height } else { 0 }
            # a la izquierda Randy (solo la parte de arriba), con los ojos a la altura de los del panda
            $rh = $dh * 0.92; $rw = if ($script:lgImg3) { $script:lgImg3.Width * $rh / $script:lgImg3.Height } else { 0 }
            $total = $(if ($script:lgImg3) { $rw * 0.82 } else { 0 }) + $dw + $(if ($script:lgImg2) { $tw2 - $dw * 0.06 } else { 0 })
            # si no cabe (ventana estrecha), se encoge todo un poco
            $esc = [Math]::Min(1.0, ($W - 16) / [Math]::Max(1.0, $total))
            $dh *= $esc; $dw *= $esc; $th2 *= $esc; $tw2 *= $esc; $rh *= $esc; $rw *= $esc; $total *= $esc
            $x0 = $W / 2 - $total / 2
            $xp = $x0 + $(if ($script:lgImg3) { $rw * 0.82 } else { 0 })
            if ($script:lgImg3) { $g.DrawImage($script:lgImg3, (New-Object System.Drawing.Rectangle([int]$x0, [int]($suelo - $dh + $dh * 0.104), [int]$rw, [int]$rh)), 0, 0, $script:lgImg3.Width, $script:lgImg3.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia) }
            $g.DrawImage($script:lgImg, (New-Object System.Drawing.Rectangle([int]$xp, [int]($suelo - $dh), [int]$dw, [int]$dh)), 0, 0, $script:lgImg.Width, $script:lgImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
            if ($script:lgImg2) { $g.DrawImage($script:lgImg2, (New-Object System.Drawing.Rectangle([int]($xp + $dw * 0.94), [int]($suelo - $th2), [int]$tw2, [int]$th2)), 0, 0, $script:lgImg2.Width, $script:lgImg2.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia) }
            $ia.Dispose()
        }
        # nombre de la empresa con líneas a los lados
        $ty = if ($script:lgImg) { $H * 0.66 } else { $H * 0.38 }
        $f1 = FntP('Georgia', 22, [System.Drawing.FontStyle]::Bold)
        $tit = 'J O S E P A B L I N I    C O R P O R A T I O N'
        $tw = $g.MeasureString($tit, $f1).Width
        # en ventanas estrechas la letra se encoge para que quepa
        if ($tw -gt $W - 150) { $f1 = FntP('Georgia', (22 * ($W - 150) / $tw), [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($tit, $f1).Width }
        $blanco = New-Object System.Drawing.SolidBrush((ARGB ([int](255 * $a)) 236 236 236))
        $g.DrawString($tit, $f1, $blanco, [float]($W / 2 - $tw / 2), [float]$ty)
        $ln = New-Object System.Drawing.Pen((ARGB ([int](150 * $a)) 200 200 200), 1)
        $g.DrawLine($ln, [float]($W / 2 - $tw / 2 - 70), [float]($ty + 17), [float]($W / 2 - $tw / 2 - 12), [float]($ty + 17))
        $g.DrawLine($ln, [float]($W / 2 + $tw / 2 + 12), [float]($ty + 17), [float]($W / 2 + $tw / 2 + 70), [float]($ty + 17)); $ln.Dispose()
        # lema: aparece un poco después
        if ($p -ge 30) {
            $b = [Math]::Min(1.0, ($p - 30) / 14.0) * $a
            $f2 = FntP('Georgia', 13, [System.Drawing.FontStyle]::Italic)
            $lema = 'Fear the Spaggety Code, Build the Larp'
            $lw = $g.MeasureString($lema, $f2).Width
            if ($lw -gt $W - 40) { $f2 = FntP('Georgia', (13 * ($W - 40) / $lw), [System.Drawing.FontStyle]::Italic); $lw = $g.MeasureString($lema, $f2).Width }
            $g.DrawString($lema, $f2, (New-Object System.Drawing.SolidBrush((ARGB ([int](255 * $b)) 160 160 160))), [float]($W / 2 - $lw / 2), [float]($ty + 44))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { try { if ($script:aj.Sonido) { (New-Object System.Media.SoundPlayer((Ruta 'skins\logo\logo.wav'))).Play() } } catch {} } }
    Intro-Overlay 130 $pintar $alTick ''
}
function Intro-Overlay($total, $pintar, $alTick, $final) {
    $script:transicion = $true
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0)
    $ov.Size = $form.ClientSize
    $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $script:iPintar = $pintar; $script:iTick = $alTick
    $ov.Add_Paint({
        $_.Graphics.ScaleTransform($script:K, $script:K)
        & $script:iPintar $_.Graphics ([int]($this.Width / $script:K)) ([int]($this.Height / $script:K)) $script:iPaso
    })
    # botón SALTAR abajo a la derecha (en todas las intros)
    $sk = New-Object System.Windows.Forms.Button
    $sk.Text = 'SALTAR  ▶▶'; $sk.FlatStyle = 'Flat'; $sk.Font = Fnt('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $sk.ForeColor = [System.Drawing.Color]::White; $sk.BackColor = (C 18 18 22); $sk.Cursor = 'Hand'
    $sk.FlatAppearance.BorderColor = [System.Drawing.Color]::White; $sk.FlatAppearance.BorderSize = [Math]::Max(1, [int](1.5 * $script:K))
    $sk.FlatAppearance.MouseOverBackColor = (C 70 70 84); $sk.FlatAppearance.MouseDownBackColor = (C 120 120 140)
    $sk.Size = New-Object System.Drawing.Size([int](100 * $script:K), [int](28 * $script:K))
    $sk.Location = New-Object System.Drawing.Point(($ov.Width - $sk.Width - [int](12 * $script:K)), ($ov.Height - $sk.Height - [int](12 * $script:K)))
    $sk.Anchor = 'Bottom, Right'
    $sk.Add_Click({ Saltar-Intro })
    $ov.Controls.Add($sk)
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:iOv = $ov; $script:iPaso = 0; $script:iTotal = $total; $script:iFinal = $final
    $iTimer.Start()
}
# salta la intro que esté sonando: corta sus sonidos y va directo al final
function Saltar-Intro {
    if (-not $script:iOv) { return }
    $script:bSaltar = $true; $script:grSaltar = $true
    foreach ($r in @($script:reproductores)) { try { $r.Stop() } catch {} }
    $script:pzMusica = $null
    if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
}

# --- "GUILLOTINA IS COMING FOR YOU!": el callejón a toda velocidad con la radio WMEW 99.9, ella bajo la farola,
#     el cartel de papel y una mandíbula de dientes negros que se come la pantalla ---
# Va sincronizada con el audio de la radio (unos 17 s), no con los fotogramas. Un clic la salta.
# Momentos de la intro (en milisegundos desde que empieza el audio):
$GuiTiempos = @{ CambioFoto = 800; Jefa = 8000; Cae = 8350; Aterriza = 8600; Cartel = 12000; Mordisco = 14800; Fin = 16300 }
# dónde está la luz de la farola en intro_jefa.jpg (en proporción de la imagen) y el alto de Guillotina
$GuiFarola = @{ X = 0.764; Suelo = 0.577; Alto = 0.407 }
# dibuja una imagen llenando la pantalla, con zoom alrededor del punto (fx, fy) de la imagen; devuelve dónde quedó
function Dibujar-Cubriendo($g, $img, $W, $H, $z, $fx, $fy) {
    $s0 = [Math]::Max($W / $img.Width, $H / $img.Height); $s = $s0 * $z
    $px = ($W - $img.Width * $s0) / 2 + $fx * $img.Width * $s0; $py = ($H - $img.Height * $s0) / 2 + $fy * $img.Height * $s0
    $x = $px - $fx * $img.Width * $s; $y = $py - $fy * $img.Height * $s
    $g.DrawImage($img, [float]$x, [float]$y, [float]($img.Width * $s), [float]($img.Height * $s))
    return @{ S = $s; X = $x; Y = $y }
}
# la mandíbula: dientes negros que bajan desde arriba y suben desde abajo (c = 0 abierta, 1 cerrada)
function Dibujar-Mandibula($g, $W, $H, $c) {
    $n = 9; $tw = $W / $n; $th = 46; $neg = [System.Drawing.Brushes]::Black
    $modo = $g.SmoothingMode; $g.SmoothingMode = 'None'   # sin suavizado: así no quedan rayas entre los dientes
    $yb = -$th + $c * ($H / 2 - $th / 2 + $th)          # borde de abajo de la mandíbula de arriba
    $yt = $H + $th - $c * ($H / 2 - $th / 2 + $th)      # borde de arriba de la mandíbula de abajo
    $g.FillRectangle($neg, 0, 0, [float]$W, [float][Math]::Max(0, $yb))
    $g.FillRectangle($neg, 0, [float]$yt, [float]$W, [float][Math]::Max(0, $H - $yt))
    for ($i = -1; $i -le $n; $i++) {
        $x = $i * $tw
        $g.FillPolygon($neg, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x, [float]$yb)), (New-Object System.Drawing.PointF([float]($x + $tw), [float]$yb)), (New-Object System.Drawing.PointF([float]($x + $tw / 2), [float]($yb + $th)))))
        $x2 = $x + $tw / 2
        $g.FillPolygon($neg, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$x2, [float]$yt)), (New-Object System.Drawing.PointF([float]($x2 + $tw), [float]$yt)), (New-Object System.Drawing.PointF([float]($x2 + $tw / 2), [float]($yt - $th)))))
    }
    if ($c -ge 0.999) { $g.FillRectangle($neg, 0, 0, [float]$W, [float]$H) }
    $g.SmoothingMode = $modo
}
# cuánto está cerrada la mandíbula: muerde, se abre un poco y vuelve a morder
function Cierre-Mandibula($t) {
    if ($t -lt 0) { return 0.0 }
    if ($t -lt 220) { $q = $t / 220.0; return $q * $q }
    if ($t -lt 380) { return 1.0 - 0.45 * (($t - 220) / 160.0) }
    if ($t -lt 560) { return 0.55 + 0.45 * (($t - 380) / 180.0) }
    return 1.0
}
function Transicion-Boss($final) {
    $k = $script:skin
    $script:bFotos = @($k.IntroFotos | ForEach-Object { Cargar-Img $_ } | Where-Object { $_ })
    $script:bJefa = Cargar-Img $k.IntroJefa; $script:bGui = Cargar-Img $k.IntroGuillotina
    $script:bCartel = Cargar-Img $k.IntroCartel; $script:bMarco = Cargar-Img $k.IntroMarco
    $script:iRecursos = @($script:bFotos) + @($script:bJefa, $script:bGui, $script:bCartel, $script:bMarco)
    $script:bT0 = 0; $script:bHechos = @{}; $script:bAudio = $null; $script:bSaltar = $false
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $T = $GuiTiempos
        $ms = if ($script:bT0 -gt 0) { [Environment]::TickCount - $script:bT0 } else { 0 }
        $g.Clear([System.Drawing.Color]::Black)
        # temblor: al cambiar de foto, al aterrizar ella y al caer el cartel
        $sx = 0; $sy = 0
        $temblor = ($ms -lt $T.Jefa -and ($ms % $T.CambioFoto) -lt 120) -or ($ms -ge $T.Aterriza -and $ms -lt $T.Aterriza + 450) -or ($ms -ge $T.Cartel -and $ms -lt $T.Cartel + 350)
        if ($temblor) { $sx = $Rnd.Next(-7, 8); $sy = $Rnd.Next(-5, 6) }
        $st = $g.Save(); $g.TranslateTransform([float]$sx, [float]$sy)
        if ($ms -lt $T.Jefa) {
            # 1) las fotos del callejón pasan rápido, cada una con un poco de zoom
            if ($script:bFotos.Count -gt 0) {
                $i = [int][Math]::Floor($ms / $T.CambioFoto) % $script:bFotos.Count; $q = ($ms % $T.CambioFoto) / $T.CambioFoto
                [void](Dibujar-Cubriendo $g $script:bFotos[$i] $W $H (1.03 + 0.07 * $q) 0.5 0.5)
            }
            if (($ms % $T.CambioFoto) -lt 70) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 255, 255, 255))), -10, -10, ($W + 20), ($H + 20)) }
        } elseif ($script:bJefa) {
            # 2) el callejón de la jefa, acercándose poco a poco a la farola; ella cae bajo la luz
            $z = 1.02 + [Math]::Min(1.0, ($ms - $T.Jefa) / 7000.0) * 0.14
            $m = Dibujar-Cubriendo $g $script:bJefa $W $H $z $GuiFarola.X 0.5
            if ($script:bGui -and $ms -ge $T.Cae) {
                $gh = $GuiFarola.Alto * $script:bJefa.Height * $m.S; $gw = $script:bGui.Width * $gh / $script:bGui.Height
                $cx = $m.X + $GuiFarola.X * $script:bJefa.Width * $m.S; $suelo = $m.Y + $GuiFarola.Suelo * $script:bJefa.Height * $m.S
                $tc = [Math]::Min(1.0, ($ms - $T.Cae) / [double]($T.Aterriza - $T.Cae)); $caida = (1 - $tc * $tc) * ($suelo + 20)   # ojo: $T son los tiempos (PowerShell no distingue mayúsculas)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](110 * $tc), 0, 0, 0))), [float]($cx - $gw * 0.45), [float]($suelo - 9), [float]($gw * 0.9), 16)
                $g.DrawImage($script:bGui, [float]($cx - $gw / 2), [float]($suelo - $gh - $caida), [float]$gw, [float]$gh)
                # polvo al aterrizar
                if ($ms -ge $T.Aterriza -and $ms -lt $T.Aterriza + 600) {
                    $q = ($ms - $T.Aterriza) / 600.0
                    foreach ($dx in @(-1, 1)) { for ($j = 0; $j -lt 3; $j++) { $r = 10 + $q * 22 + $j * 5; $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](120 * (1 - $q)), 200, 200, 200))), [float]($cx + $dx * ($gw * 0.42 + $q * 40 + $j * 14) - $r / 2), [float]($suelo - $r * 0.8), [float]$r, [float]($r * 0.7)) } }
                }
            }
        }
        # el marco de cables, postes y basura por delante de todo
        if ($script:bMarco) { [void](Dibujar-Cubriendo $g $script:bMarco $W $H 1.0 0.5 0.5) }
        $g.Restore($st)
        # 3) el cartel de papel cae de golpe
        if ($script:bCartel -and $ms -ge $T.Cartel) {
            $q = ($ms - $T.Cartel) / 160.0; $esc = 1.0 + 0.9 * [Math]::Max(0.0, 1 - $q)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]([Math]::Min(1.0, $q) * 120), 0, 0, 0))), 0, 0, $W, $H)
            $ch = $H * 0.74; $cw = $script:bCartel.Width * $ch / $script:bCartel.Height
            $st = $g.Save(); $g.TranslateTransform([float]($W / 2 + $sx), [float]($H / 2 + $sy)); $g.RotateTransform(-2); $g.ScaleTransform([float]$esc, [float]$esc)
            $g.DrawImage($script:bCartel, [float](-$cw / 2), [float](-$ch / 2), [float]$cw, [float]$ch)
            $g.Restore($st)
        }
        # 4) la mandíbula se come la pantalla
        if ($ms -ge $T.Mordisco) { Dibujar-Mandibula $g $W $H (Cierre-Mandibula ($ms - $T.Mordisco)) }
    }
    $alTick = {
        param($ov, $p)
        $T = $GuiTiempos
        if ($p -eq 1) {
            $script:bT0 = [Environment]::TickCount
            # la radio; se guarda el reproductor para poder pararla si se salta la intro
            if ($script:aj.Sonido) { $n = $script:reproductores.Count; Sonido 'radio'; if ($script:reproductores.Count -gt $n -or $script:reproductores.Count -ge 12) { $script:bAudio = $script:reproductores[$script:reproductores.Count - 1] } }
        }
        $ms = [Environment]::TickCount - $script:bT0
        foreach ($ev in @(@($T.Aterriza, 'golpe'), @($T.Cartel, 'intro'), @(($T.Mordisco + 220), 'mordisco'), @(($T.Mordisco + 560), 'mordisco2'))) {
            if ($ms -ge $ev[0] -and -not $script:bHechos.ContainsKey($ev[1])) { $script:bHechos[$ev[1]] = $true; Sonido ($ev[1] -replace '2$', '') }
        }
        if ($script:bSaltar -or $ms -ge $T.Fin) {
            if ($script:bSaltar -and $script:bAudio) { try { $script:bAudio.Stop() } catch {} }
            if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        }
    }
    Intro-Overlay 2000 $pintar $alTick $final
    # un clic salta la intro
    $script:iOv.Add_MouseDown({ $script:bSaltar = $true })
    $script:iOv.Cursor = 'Hand'
}

# --- inicio de jornada en L Corp ---
function Transicion-Lobo($final) {
    if (-not $script:bmpHexIntro) { $script:bmpHexIntro = Fondo-Hexagonos 616 344 ([System.Drawing.Color]::FromArgb(60, 255, 170, 40)) }
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
        $g.Clear((C 6 8 11))
        if ($p -ge 2) { $g.DrawImage($script:bmpHexIntro, 0, 0, 616, 344) }
        $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
        $t1 = 'LOBOTOMY CORPORATION'
        $n = [Math]::Min($t1.Length, [Math]::Max(0, $p - 3))
        $g.DrawString($t1.Substring(0, $n), (FntP('Bahnschrift', 24, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 176 50))), (New-Object System.Drawing.RectangleF(0, ($H / 2 - 92), $W, 44)), $fmt)
        if ($p -ge 24) { $g.DrawString('Face the Fear, Build the Future', (FntP('Bahnschrift', 11)), (New-Object System.Drawing.SolidBrush((C 80 210 200))), (New-Object System.Drawing.RectangleF(0, ($H / 2 - 48), $W, 24)), $fmt) }
        if ($p -ge 32) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 176 50))), ($W / 2 - 160), ($H / 2 - 16), 320, 2) }
        if ($p -ge 34) { $g.DrawString("DÍA $($script:dia)", (FntP('Bahnschrift', 30, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, ($H / 2 - 8), $W, 54)), $fmt) }
        if ($p -ge 42) { $g.DrawString('Manager conectado.  Angela: en línea.', (FntP('Bahnschrift', 9)), (New-Object System.Drawing.SolidBrush((C 140 150 160))), (New-Object System.Drawing.RectangleF(0, ($H / 2 + 50), $W, 20)), $fmt) }
    }
    # al final se abre como dos puertas desde el centro
    $alTick = {
        param($ov, $p)
        if ($p -gt 50) {
            $W = $ov.Width; $H = $ov.Height; $banda = [int]($W * ($p - 50) / 10)
            $reg = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
            $reg.Exclude((New-Object System.Drawing.Rectangle([int](($W - $banda) / 2), 0, $banda, $H)))
            $viejo = $ov.Region; $ov.Region = $reg; if ($viejo) { $viejo.Dispose() }
        }
    }
    Intro-Overlay 61 $pintar $alTick $final
}

# --- la mira del francotirador de Mikaela ---
function Transicion-Scope($final) {
    $script:scRet = Cargar-Img $script:skin.Gif; $script:scPlaca = Cargar-Img $script:skin.TituloImg
    $script:iRecursos = @($script:scRet, $script:scPlaca)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'
        $g.Clear([System.Drawing.Color]::Black)
        $amp = [Math]::Max(0.0, 1 - $p / 24.0)
        $cx = $W / 2 + [Math]::Sin($p / 2.5) * 80 * $amp; $cy = $H / 2 + [Math]::Cos($p / 3.3) * 38 * $amp; $r = 118
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse([float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
        $g.SetClip($path)
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (C 57 72 191), (C 229 45 45), 35)
        $g.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
        $s = [int](250 * (1.0 + [Math]::Min($p, 30) * 0.012))
        if ($script:scRet) { $g.DrawImage($script:scRet, [int]($W / 2 - $s / 2), [int]($H / 2 - $s / 2), $s, $s) }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
        $g.DrawLine($pen, [float]($cx - $r), [float]$cy, [float]($cx + $r), [float]$cy); $g.DrawLine($pen, [float]$cx, [float]($cy - $r), [float]$cx, [float]($cy + $r))
        for ($q = -3; $q -le 3; $q++) { if ($q) { $g.DrawLine($pen, [float]($cx + $q * 25), [float]($cy - 5), [float]($cx + $q * 25), [float]($cy + 5)) } }
        $pen.Dispose()
        $g.FillEllipse([System.Drawing.Brushes]::Red, [float]($cx - 4), [float]($cy - 4), 8, 8)
        $g.ResetClip()
        $g.DrawEllipse((New-Object System.Drawing.Pen((C 30 30 30), 10)), [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
        $path.Dispose()
        $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
        if ($p -lt 30) {
            if ($p -lt 12) { $txt = 'APUNTANDO...'; $col = [System.Drawing.Brushes]::White } elseif ($p -lt 22) { $txt = 'CHARGED'; $col = [System.Drawing.Brushes]::Yellow } else { $txt = 'OVERCHARGED'; $col = [System.Drawing.Brushes]::Red }
            $g.DrawString($txt, (FntP('Arial Black', 12)), $col, (New-Object System.Drawing.RectangleF(0, ($H - 34), $W, 30)), $fmt)
        }
        if ($p -ge 31) {
            Dibujar-Hit $g ($W / 2) ($H / 2) 30
            if ($script:scPlaca) { $g.DrawImage($script:scPlaca, [int]($W / 2 - 150), 8, 300, 94) }
            Texto-Borde $g 'THE MVP' 'Arial Black' 30 ($W / 2 - 92) ($H - 66) (C 0 255 0)
        }
        if ($p -ge 30 -and $p -le 33) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb((34 - $p) * 60, 255, 255, 255))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        switch ($p) { 1 { Sonido 'apuntar' } 12 { Sonido 'carga' } 22 { Sonido 'sobrecarga' } 30 { Sonido 'disparoMax' } }
        if ($p -gt 44) { $ov.Left -= [int]($ov.Width / 6) }
    }
    Intro-Overlay 51 $pintar $alTick $final
}

# --- pantalla de selección de personaje de Gunsaw (Velvet y Dune) ---
function Transicion-Gunsaw($final) {
    $script:gaArte = Cargar-Img $script:skin.Arte
    $script:iRecursos = @($script:gaArte)
    $pintar = {
        param($g, $W, $H, $p)
        $k = $script:skin
        $g.Clear((C 24 13 28)); $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
        $lin = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(18, 255, 255, 255), 1)
        for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($lin, 0, $y, $W, $y) }
        $lin.Dispose()
        $blanco = New-Object System.Drawing.SolidBrush((C 222 218 226)); $gris = New-Object System.Drawing.Pen((C 125 112 130), 1)
        if ($p -ge 2) { $g.DrawString('A-D to switch characters', (FntP('Consolas', 9, [System.Drawing.FontStyle]::Bold)), $blanco, 214, 6) }
        $n = [Math]::Min($k.Titulo.Length, [Math]::Max(0, $p - 3))
        $g.DrawString($k.Titulo.Substring(0, $n), (FntP('Consolas', 28, [System.Drawing.FontStyle]::Bold)), $blanco, 14, 10)
        if ($p -ge 8) { $g.DrawString('14/14 species unlocked', (FntP('Consolas', 9)), (New-Object System.Drawing.SolidBrush((C 190 184 196))), 18, 58) }
        if ($p -ge 4 -and $script:gaArte -and -not ($p -lt 16 -and $Rnd.Next(4) -eq 0)) {
            $x = 380 + [Math]::Max(0, 12 - $p) * 18
            $g.DrawImage($script:gaArte, [int]$x, 8, 226, 270)
        }
        if ($p -ge 10) {
            $g.DrawString('Character', (FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold)), $blanco, 16, 84)
            $g.DrawRectangle($gris, 16, 104, 354, 118)
            $quedan = ($p - 10) * 7; $y = 110
            foreach ($l in $k.IntroLineas) {
                if ($quedan -le 0) { break }
                $t = $l.Substring(0, [Math]::Min($l.Length, $quedan)); $quedan -= $l.Length
                $g.DrawString($t, (FntP('Consolas', 7.5)), $blanco, 22, $y); $y += 18
            }
        }
        if ($p -ge 30) {
            $g.DrawString('Gameplay', (FntP('Consolas', 11, [System.Drawing.FontStyle]::Bold)), $blanco, 16, 226)
            $g.DrawRectangle($gris, 16, 246, 262, 52)
            $y = 250; foreach ($l in $k.IntroStats) { Texto-Marcado $g $l (FntP('Consolas', 7.5, [System.Drawing.FontStyle]::Bold)) 22 $y; $y += 12 }
            foreach ($l in $k.IntroPie) { Texto-Marcado $g $l (FntP('Consolas', 7.5, [System.Drawing.FontStyle]::Bold)) 22 $y; $y += 12 }
            $g.DrawRectangle($gris, 284, 246, 86, 52)
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString("Starting weapon:`n$($k.Arma)", (FntP('Consolas', 7, [System.Drawing.FontStyle]::Bold)), $blanco, (New-Object System.Drawing.RectangleF(284, 252, 86, 44)), $fmt)
        }
        if ($p -ge 40 -and ($p % 6) -lt 4) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 28 44))), ($W - 150), ($H - 36), 136, 24)
            $g.DrawRectangle($gris, ($W - 150), ($H - 36), 136, 24)
            $g.DrawString('BACK TO LEVEL', (FntP('Consolas', 10, [System.Drawing.FontStyle]::Bold)), $blanco, ($W - 142), ($H - 33))
        }
        $marco = Ruta-Redonda 2 2 ($W - 4) ($H - 4) 26
        $g.DrawPath((New-Object System.Drawing.Pen((C 10 4 12), 6)), $marco); $marco.Dispose()
        $gris.Dispose(); $blanco.Dispose()
    }
    # al final el monitor "se apaga" hasta quedar en una línea y un punto
    $alTick = {
        param($ov, $p)
        if ($p -gt 50) {
            $W = $ov.Width; $H = $ov.Height
            if ($p -ge 57) { $rc = New-Object System.Drawing.Rectangle([int]($W / 2 - 8), [int]($H / 2 - 3), 16, 6) }
            else { $alto = [Math]::Max(4, [int]($H * (1 - ($p - 50) / 7.0))); $rc = New-Object System.Drawing.Rectangle(0, [int](($H - $alto) / 2), $W, $alto) }
            $viejo = $ov.Region; $ov.Region = New-Object System.Drawing.Region($rc); if ($viejo) { $viejo.Dispose() }
        }
    }
    Intro-Overlay 60 $pintar $alTick $final
}

# --- duelo al atardecer: plano general, primer plano de los ojos, "DON'T MOVE!", tres balazos y su cartel ---
function Transicion-Wanted($final) {
    $script:wpImg = Cargar-Img $script:skin.Cartel
    $script:wpCielo = $null; $script:wpSil = $null
    # silueta negra de Zodiac (el mismo dibujo, pintado de negro) para el contraluz
    if ($script:wpImg) {
        $sh = 300; $sw = [int]($script:wpImg.Width * $sh / $script:wpImg.Height)
        $script:wpSil = New-Object System.Drawing.Bitmap($sw, $sh)
        $gs = [System.Drawing.Graphics]::FromImage($script:wpSil); $gs.InterpolationMode = 'HighQualityBicubic'
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        $cm.Matrix00 = 0; $cm.Matrix11 = 0; $cm.Matrix22 = 0; $cm.Matrix40 = 0.13; $cm.Matrix41 = 0.04; $cm.Matrix42 = 0.08
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $gs.DrawImage($script:wpImg, (New-Object System.Drawing.Rectangle(0, 0, $sw, $sh)), 0, 0, $script:wpImg.Width, $script:wpImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $gs.Dispose(); $ia.Dispose()
    }
    $script:iRecursos = @($script:wpImg, $script:wpSil)
    $script:agujeros = New-Object System.Collections.ArrayList
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        # el atardecer se pinta una vez y se reutiliza
        if (-not $script:wpCielo) {
            $Z = $script:K
            $script:wpCielo = New-Object System.Drawing.Bitmap([int]($W * $Z), [int]($H * $Z))
            $gc = [System.Drawing.Graphics]::FromImage($script:wpCielo); $gc.SmoothingMode = 'AntiAlias'; $gc.ScaleTransform($Z, $Z)
            Pintar-Atardecer $gc 0 0 $W $H ($H * 0.66) ($W * 0.5) 78
            Cactus-Silueta $gc 70 ($H - 20) 200 (C 34 12 24)
            Cactus-Silueta $gc ($W - 90) ($H * 0.66 + 6) 60 (C 92 30 52)
            $gc.Dispose(); $script:iRecursos += $script:wpCielo
        }
        $sx = 0; $sy = 0
        if (($p -ge 32 -and $p -le 35) -or $p -in @(40, 41, 43, 44, 46, 47)) { $sx = $Rnd.Next(-9, 10); $sy = $Rnd.Next(-6, 7) }
        $barra = 0
        if ($p -lt 16) {
            # 1) plano general: el desierto al atardecer y una planta rodadora
            $g.DrawImage($script:wpCielo, 0, 0, $W, $H)
            Dibujar-Rodadora $g (-40 + $p * 34) ($H * 0.82 - [Math]::Abs([Math]::Sin($p * 0.6)) * 22) 22 ($p * 26)
            $barra = [Math]::Min(46, $p * 8)
        } elseif ($p -lt 30) {
            # 2) primer plano de los ojos (como en las pelis del oeste)
            $g.Clear((C 20 8 10))
            if ($script:wpImg) {
                $z = 1 + ($p - 16) * 0.012
                $sw = 400 / $z; $sh = 112 / $z
                $src = New-Object System.Drawing.RectangleF([float](405 - $sw / 2), [float](346 - $sh / 2), [float]$sw, [float]$sh)
                $g.DrawImage($script:wpImg, (New-Object System.Drawing.RectangleF(0, [float]($H * 0.5 - 100), [float]$W, 200)), $src, [System.Drawing.GraphicsUnit]::Pixel)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 60 255 90 30))), 0, 0, $W, $H)
            }
            $barra = $H * 0.5 - 100
        } else {
            # 3) contraluz delante del sol, "DON'T MOVE!", balazos y cartel
            $g.DrawImage($script:wpCielo, [float](-14 + $sx), [float](-10 + $sy), [float]($W + 28), [float]($H + 20))
            if ($script:wpSil) {
                $ch = $H * 0.86; $cw = $script:wpSil.Width * $ch / $script:wpSil.Height
                $cx = $W * 0.5 - $cw / 2 + $sx; $cy = $H - $ch - 4 + $sy
                if ($p -ge 50) { $cx = $cx + [Math]::Min(1.0, ($p - 50) / 6.0) * ($W * 0.2) }
                $g.DrawImage($script:wpSil, [float]$cx, [float]$cy, [float]$cw, [float]$ch)
                # al final se le ve en color
                if ($p -ge 50 -and $script:wpImg) {
                    $al = [float][Math]::Min(1.0, ($p - 50) / 6.0)
                    $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = $al
                    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                    $g.DrawImage($script:wpImg, (New-Object System.Drawing.Rectangle([int]$cx, [int]$cy, [int]$cw, [int]$ch)), 0, 0, $script:wpImg.Width, $script:wpImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
                    $ia.Dispose()
                }
            }
            if ($p -ge 32 -and $p -lt 50) {
                $e = [Math]::Max(1.0, 2.2 - ($p - 32) * 0.4)
                $st = $g.Save(); $g.TranslateTransform([float]($W / 2 + $sx), [float]($H * 0.42 + $sy)); $g.RotateTransform(-10); $g.ScaleTransform([float]$e, [float]$e)
                Texto-Color $g "DON'T MOVE!" 'EdmundMcMillen_INTLv4' 62 (-185) (-42) (C 235 46 34) (C 255 226 120) 12
                $g.Restore($st)
            }
            # agujeros de bala con el cristal roto
            foreach ($a in $script:agujeros) {
                $gr = New-Object System.Drawing.Pen((ARGB 200 255 255 255), 1.4)
                foreach ($k in 0..7) { $an = ($k * 45 + $a.R) * [Math]::PI / 180; $l = 18 + (($k * 7 + $a.R) % 22); $g.DrawLine($gr, [float]$a.X, [float]$a.Y, [float]($a.X + [Math]::Cos($an) * $l), [float]($a.Y + [Math]::Sin($an) * $l)) }
                $g.DrawEllipse($gr, [float]($a.X - 11), [float]($a.Y - 11), 22, 22); $gr.Dispose()
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 10 6 6))), [float]($a.X - 5), [float]($a.Y - 5), 10, 10)
                # humito
                if ($p -ge $a.P) { $hy = ($p - $a.P) * 2.5; $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB ([int][Math]::Max(0, 120 - ($p - $a.P) * 5)) 230 220 210))), [float]($a.X - 6 + [Math]::Sin($p * 0.5) * 3), [float]($a.Y - 14 - $hy), 12, 12) }
            }
            if ($p -in @(40, 43, 46)) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 255 244 200))), 0, 0, $W, $H) }
            # título del cartel
            if ($p -ge 52) {
                $t = [Math]::Min(1.0, ($p - 52) / 5.0); $e = 1 - [Math]::Pow(1 - $t, 3)
                $tx = -360 + $e * 384
                Texto-Color $g 'ZODIAC' 'EdmundMcMillen_INTLv4' 76 ($tx + 5) 44 (ARGB 120 40 10 20) (ARGB 120 40 10 20) 14
                Texto-Color $g 'ZODIAC' 'EdmundMcMillen_INTLv4' 76 $tx 38 (C 255 214 90) (C 60 20 12) 14
            }
            if ($p -ge 58) {
                $t = [Math]::Min(1.0, ($p - 58) / 4.0); $wcin = 330 * $t
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 176 36 34))), 22, 138, [float]$wcin, 34)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 20 22))), 22, 168, [float]$wcin, 4)
                if ($t -ge 1) { Texto-Color $g 'SE BUSCA  ·  VIVO O MUERTO' 'EdmundMcMillen_INTLv4' 20 34 142 (C 255 236 205) (C 60 10 10) 4 }
            }
            if ($p -ge 62) { Texto-Color $g 'RECOMPENSA: 6 BALAS' 'EdmundMcMillen_INTLv4' 18 30 182 (C 255 214 120) (C 40 14 6) 5 }
        }
        # franjas de cine
        if ($barra -gt 0) {
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, [float]$barra)
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, [float]($H - $barra), $W, [float]$barra)
            if ($p -ge 4 -and $p -lt 16) {
                $txt = 'EL DESIERTO.  LAS DOCE EN PUNTO.'; $txt = $txt.Substring(0, [Math]::Min($txt.Length, ($p - 4) * 3))
                $g.DrawString($txt, (FntP('EdmundMcMillen_INTLv4', 13)), (New-Object System.Drawing.SolidBrush((C 255 214 140))), 18, [float]($H - $barra + 12))
            }
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { Sonido 'viento' }
        if ($p -eq 18) { Sonido 'loco' }
        if ($p -eq 32) { Sonido 'grito' }
        if ($p -in @(40, 43, 46)) { Sonido 'bang'; [void]$script:agujeros.Add(@{ X = $Rnd.Next(60, 700); Y = $Rnd.Next(40, 260); R = $Rnd.Next(0, 40); P = $p }) }
        if ($p -eq 52) { Sonido 'recarga' }
        if ($p -gt 74) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 80 $pintar $alTick $final
}

# --- INSERT TOKEN: la ficha cae en la recreativa, el logo en llamas, cortes con las portadas oficiales y el cartel final ---
function Transicion-Token($final) {
    $script:tkPort = @(for ($i = 1; $i -le 8; $i++) { Cargar-Img "skins\token\portada$i.jpg" })
    $script:tkFuego = Cargar-Img $script:skin.Logo
    $script:iRecursos = @($script:tkPort) + @($script:tkFuego)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $rn = New-Object System.Random ($p * 31 + 7)
        if ($p -lt 12) {
            # 1) estática y "INSERT TOKEN"; la ficha cae por la ranura
            $g.Clear((C 6 4 6))
            for ($i = 0; $i -lt 260; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $rn.Next(40, 160) 255 255 255))), $rn.Next(0, $W), $rn.Next(0, $H), $rn.Next(1, 4), 1) }
            if ($p % 4 -lt 3) { Texto-Color $g 'INSERT TOKEN' 'Consolas' 34 ($W / 2 - 128) ($H / 2 - 64) (C 255 255 255) (C 230 20 40) 4 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 60 60 66))), ($W / 2 - 34), ($H / 2 + 34), 68, 10)
            $g.FillRectangle([System.Drawing.Brushes]::Black, ($W / 2 - 22), ($H / 2 + 37), 44, 4)
            if ($p -lt 9) {
                $cy = -30 + $p * (($H / 2 + 34) / 8.0)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 206 70))), [float]($W / 2 - 14), [float]$cy, 28, 28)
                $g.DrawEllipse((New-Object System.Drawing.Pen((C 160 110 20), 2)), [float]($W / 2 - 14), [float]$cy, 28, 28)
                Texto-Color $g 'T' 'Arial Black' 14 ($W / 2 - 6) ($cy + 4) (C 160 110 20) (C 255 230 140) 1
            }
            $cred = if ($p -ge 9) { 'CREDIT 01' } else { 'CREDIT 00' }
            $g.DrawString($cred, (FntP('Consolas', 12, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, ($W - 120), ($H - 28))
        } elseif ($p -lt 24) {
            # 2) el logo de femtanyl en llamas, temblando
            $g.Clear($(if ($p -in @(12, 13)) { (C 120 0 14) } else { (C 6 4 6) }))
            if ($script:tkFuego) {
                $e = [Math]::Max(1.0, 1.6 - ($p - 12) * 0.12)
                $lh = $H * 0.8 * $e; $lw = $script:tkFuego.Width * $lh / $script:tkFuego.Height
                $g.DrawImage($script:tkFuego, [float]($W / 2 - $lw / 2 + $rn.Next(-5, 6)), [float]($H / 2 - $lh / 2 + $rn.Next(-4, 5)), [float]$lw, [float]$lh)
            }
            for ($i = 0; $i -lt 5; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 230 20 40))), 0, $rn.Next(0, $H), $W, $rn.Next(1, 5)) }
        } elseif ($p -lt 52) {
            # 3) cortes rápidos: una portada oficial y una palabra cada pocos fotogramas
            $c = [int](($p - 24) / 3); $rc = New-Object System.Random ($c * 7 + 3)
            $g.Clear($(if ($c % 2 -eq 0) { (C 6 4 6) } else { (C 70 0 10) }))
            $im = $script:tkPort[$c % 8]
            if ($im) {
                $lado = 190 + $rc.Next(0, 70)
                $st = $g.Save(); $g.TranslateTransform([float]($W * 0.62 + $rc.Next(-60, 60)), [float]($H / 2 + $rc.Next(-20, 20))); $g.RotateTransform([float]$rc.Next(-9, 10))
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float](-$lado / 2 + 6), [float](-$lado / 2 + 6), [float]($lado + 12), [float]($lado + 12))
                $g.FillRectangle([System.Drawing.Brushes]::White, [float](-$lado / 2 - 6), [float](-$lado / 2 - 6), [float]($lado + 12), [float]($lado + 12))
                $g.DrawImage($im, [float](-$lado / 2), [float](-$lado / 2), [float]$lado, [float]$lado)
                $g.Restore($st)
            }
            $pal = $TokenCanciones[$c % 8]
            $st = $g.Save(); $g.TranslateTransform([float]$rc.Next(20, 120), [float]$rc.Next(50, [int]($H - 80))); $g.RotateTransform([float]$rc.Next(-10, 11))
            Texto-Color $g $pal 'Arial Black' (26 + $rc.Next(0, 12)) 0 0 (C 255 255 255) (C 230 20 40) 6
            $g.Restore($st)
            $sl = New-Object System.Drawing.Pen((ARGB 60 0 0 0), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($sl, 0, $y, $W, $y) }; $sl.Dispose()
        } else {
            # 4) cartel final: rayos rojos, la portada de AND IM GONE y su nombre
            $g.Clear((C 6 4 6))
            $cx = $W * 0.7; $cy = $H * 0.5; $rot = $p * 3
            $br = New-Object System.Drawing.SolidBrush((ARGB 90 230 20 40))
            for ($i = 0; $i -lt 14; $i++) {
                $a1 = [Math]::PI / 180 * ($rot + $i * 25.7 - 6); $a2 = [Math]::PI / 180 * ($rot + $i * 25.7 + 6)
                $g.FillPolygon($br, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$cx, [float]$cy)), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a1)), [float]($cy + 900 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a2)), [float]($cy + 900 * [Math]::Sin($a2))))))
            }
            $br.Dispose()
            $im = $script:tkPort[0]
            if ($im) {
                $lado = $H * 0.78
                $st = $g.Save(); $g.TranslateTransform([float]$cx, [float]$cy); $g.RotateTransform(-4)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float](-$lado / 2 + 8), [float](-$lado / 2 + 8), [float]($lado + 14), [float]($lado + 14))
                $g.FillRectangle([System.Drawing.Brushes]::White, [float](-$lado / 2 - 7), [float](-$lado / 2 - 7), [float]($lado + 14), [float]($lado + 14))
                $g.DrawImage($im, [float](-$lado / 2 + $rn.Next(-2, 3)), [float](-$lado / 2), [float]$lado, [float]$lado)
                $g.Restore($st)
            }
            $t = [Math]::Min(1.0, ($p - 52) / 5.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            Texto-Color $g 'TOKEN' 'Arial Black' 78 (-380 + $e * 404) 56 (C 255 255 255) (C 230 20 40) 10
            if ($p -ge 56) { Texto-Color $g 'femtanyl' 'Consolas' 26 30 160 (C 255 60 70) (C 0 0 0) 4 }
            if ($p -ge 59) { Texto-Color $g 'T0K3N 1NS3RT3D' 'Consolas' 16 32 200 (C 255 255 255) (C 0 0 0) 3 }
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { Sonido 'glitch' }
        if ($p -eq 9) { Sonido 'moneda' }
        if ($p -eq 12) { Sonido 'golpe' }
        if ($p -eq 24) { Sonido 'breakcore' }
        if ($p -eq 52) { Sonido 'golpe' }
        if ($p -gt 68) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 74 $pintar $alTick $final
}
# --- cinta VHS: pantalla azul, PLAY, escenas del videoclip y el cartel de neón de "Pop Music" ---
function Transicion-Pop($final) {
    $script:ppFotos = @($script:skin.Fotos | ForEach-Object { Cargar-Img $_ })
    $script:ppImg = Cargar-Img $script:skin.Gif; $script:ppLogo = Cargar-Img $script:skin.Logo
    $script:ppRosa = Imagen-Color $script:ppImg (C 255 70 190) 300; $script:ppCian = Imagen-Color $script:ppImg (C 60 230 255) 300
    $script:iRecursos = @($script:ppFotos) + @($script:ppImg, $script:ppLogo, $script:ppRosa, $script:ppCian)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $rn = New-Object System.Random ($p * 17 + 1)
        if ($p -ge 8 -and $p -lt 46) { $g.InterpolationMode = 'Bilinear' }
        $osd = FntP('Consolas', 15, [System.Drawing.FontStyle]::Bold)
        if ($p -lt 8) {
            # 1) pantalla azul del vídeo y "PLAY"
            $g.Clear((C 24 34 196))
            for ($i = 0; $i -lt 6; $i++) { $y = ($H - 60 + $p * 9 + $i * 7) % $H; $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 255 255 255))), $rn.Next(-100, 200), $y, $rn.Next(200, $W), 2) }
            $g.DrawString('PLAY ▶', $osd, [System.Drawing.Brushes]::White, 26, 22)
            $g.DrawString('SP', $osd, [System.Drawing.Brushes]::White, ($W - 70), 22)
        } elseif ($p -lt 46) {
            # 2) escenas del videoclip con la imagen temblando como una cinta vieja
            $i = [Math]::Min($script:ppFotos.Count - 1, [int](($p - 8) / 7.6)); $img = $script:ppFotos[$i]
            if ($img) {
                $s = [Math]::Max($W / $img.Width, $H / $img.Height); $sw = $W / $s; $sh = $H / $s; $ox = ($img.Width - $sw) / 2; $oy = ($img.Height - $sh) / 2
                $g.DrawImage($img, (New-Object System.Drawing.RectangleF(0, 0, [float]$W, [float]$H)), (New-Object System.Drawing.RectangleF([float]$ox, [float]$oy, [float]$sw, [float]$sh)), [System.Drawing.GraphicsUnit]::Pixel)
                # franjas desplazadas
                for ($k2 = 0; $k2 -lt 3; $k2++) {
                    $by = $rn.Next(0, [int]($H - 20)); $bh = $rn.Next(4, 18); $dx = $rn.Next(-14, 15)
                    $g.DrawImage($img, (New-Object System.Drawing.RectangleF([float]$dx, [float]$by, [float]$W, [float]$bh)), (New-Object System.Drawing.RectangleF([float]$ox, [float]($oy + $by / $s), [float]$sw, [float]($bh / $s))), [System.Drawing.GraphicsUnit]::Pixel)
                }
            }
            # banda de "tracking" que baja
            $ty = (($p * 23) % ($H + 40)) - 20
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 255 255 255))), 0, $ty, $W, 8)
            for ($i2 = 0; $i2 -lt 30; $i2++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 255 255 255))), $rn.Next(0, $W), ($ty + $rn.Next(0, 8)), $rn.Next(2, 20), 1) }
            # al cambiar de escena, un destello
            if ((($p - 8) % 7.6) -lt 1) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 255 255 255))), 0, 0, $W, $H) }
            $g.DrawString('PLAY ▶', $osd, [System.Drawing.Brushes]::White, 26, 22)
            $seg = [int](($p - 8) * 0.045 * 10)
            $g.DrawString(('SP  0:00:{0:00}' -f $seg), $osd, [System.Drawing.Brushes]::White, ($W - 170), 22)
        } else {
            # 3) cartel final de neón
            $img = $script:ppFotos[0]
            if ($img) { Imagen-Cubrir $g $img 0 0 $W $H 0.5 0.5 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 30 10 60))), 0, 0, $W, $H)
            # Tetra entra desde la derecha dejando un rastro de colores
            $t = [Math]::Min(1.0, ($p - 46) / 7.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            $th = $H * 0.94; $tw = $script:ppImg.Width * $th / $script:ppImg.Height
            $tx = $W + 20 - $e * ($tw + 70); $ty = $H - $th + 4 + [Math]::Abs([Math]::Sin($p * 0.4)) * -6
            Dibujar-RGB $g $script:ppImg $script:ppRosa $script:ppCian $tx $ty $tw $th (3 + (1 - $e) * 22)
            if ($p -ge 50) {
                $g.DrawString("you're just like", (FntP('Consolas', 15, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 60, 58)
                $q = [Math]::Min(1.0, ($p - 50) / 4.0); $al = [int](255 * $q)
                Texto-Color $g 'Pop Music' 'Brush Script MT' 78 30 76 (ARGB $al 255 92 190) (ARGB ([int]($al * 0.35)) 255 92 190) 16
                Texto-Color $g 'Pop Music' 'Brush Script MT' 78 30 76 (ARGB $al 90 230 250) (ARGB $al 255 255 255) 2
            }
            if ($p -ge 56) {
                Texto-Color $g 'TETRA' 'Arial Black' 30 64 196 (C 255 255 255) (C 255 92 190) 5
                $g.DrawString('YonKaGor', (FntP('Consolas', 12, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 214 120))), 70, 240)
            }
            if ($script:ppLogo -and $p -ge 58) { $g.DrawImage($script:ppLogo, 300, 196, 78, 60) }
            $sl = New-Object System.Drawing.Pen((ARGB 40 0 0 0), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($sl, 0, $y, $W, $y) }; $sl.Dispose()
            $g.DrawString($(if ($p -ge 66) { 'STOP ■' } else { 'PLAY ▶' }), $osd, [System.Drawing.Brushes]::White, 26, 18)
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { Sonido 'vhs' }
        if ($p -eq 8) { Sonido 'disco' }
        if ($p -eq 50) { Sonido 'ping' }
        if ($p -gt 68) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 74 $pintar $alTick $final
}
# --- Gran: la intro de su personaje en el vídeo de ANTIHUMAN (rayas grises, remolino de pintura, su cara y el busto
#     con la jeringuilla), tal cual, con su canción. Va por tiempo, no por fotogramas. Un clic la salta. ---
function Transicion-Gran($final) {
    $script:grIntro = Cargar-Img $script:skin.IntroImg
    $script:grIntroInfo = if ($script:grIntro) { Gif-Info $script:grIntro } else { @{ N = 1; Del = @(100) } }
    $script:grIntroMs = 0; foreach ($d in $script:grIntroInfo.Del) { $script:grIntroMs += $d }
    $script:grT0 = 0; $script:grSaltar = $false
    $script:iRecursos = @($script:grIntro)
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $img = $script:grIntro; if (-not $img) { return }
        $ms = if ($script:grT0 -gt 0) { [Environment]::TickCount - $script:grT0 } else { 0 }
        Gif-Frame $img $script:grIntroInfo ([Math]::Min($ms, $script:grIntroMs - 1))
        # el vídeo entero, sin recortar (bandas negras a los lados)
        $s = [Math]::Min($W / $img.Width, $H / $img.Height); $vw = $img.Width * $s; $vh = $img.Height * $s
        $g.InterpolationMode = 'HighQualityBilinear'
        $g.DrawImage($img, [float](($W - $vw) / 2), [float](($H - $vh) / 2), [float]$vw, [float]$vh)
        # se funde a negro al final
        $resta = $script:grIntroMs - $ms
        if ($resta -lt 400) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int](255 * [Math]::Max(0.0, [Math]::Min(1.0, 1 - $resta / 400.0)))) 0 0 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { $script:grT0 = [Environment]::TickCount; Gran-Musica-On $true }
        $ms = [Environment]::TickCount - $script:grT0
        if ($script:grSaltar -or $ms -ge $script:grIntroMs) {
            if ($script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        }
    }
    Intro-Overlay 2000 $pintar $alTick $final
    $script:iOv.Add_MouseDown({ $script:grSaltar = $true })
    $script:iOv.Cursor = 'Hand'
}
# --- Enfosi: la portada del juego, "conoce a tus Glaggles", uno se revela, el Ojo de Enphoso y la primera oleada ---
function Transicion-Enfosi($final) {
    $script:enIn = @{}
    foreach ($n in @('portada.jpg', 'logo.png', 'ojo.png', 'enphoso_titulo.png', 'giggler_oleada.png', 'gembo_enfosi.png')) { $script:enIn[$n] = Cargar-Img "skins\enfosi\$n" }
    foreach ($t in $EnfosiTipos) { $script:enIn[$t] = Cargar-Img "skins\enfosi\$t.png" }
    $script:iRecursos = @($script:enIn.Values)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $sx = 0; $sy = 0; if ($p -ge 44 -and $p -le 50) { $sx = $Rnd.Next(-8, 9); $sy = $Rnd.Next(-6, 7) }
        if ($p -lt 52) {
            # portada del juego (un Giggler con un arma y un Enphoso detrás), con un poco de zoom
            $z = 1 + $p * 0.002
            $im = $script:enIn['portada.jpg']
            if ($im) { Imagen-Cubrir $g $im (-$W * ($z - 1) / 2 + $sx) (-$H * ($z - 1) / 2 + $sy) ($W * $z) ($H * $z) 0.5 0.5 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $(if ($p -lt 14) { 90 } else { 170 }) 10 10 20))), 0, 0, $W, $H)
            # logo de los Glaggles que cae
            $lg = $script:enIn['logo.png']
            if ($lg) {
                $t = [Math]::Min(1.0, $p / 8.0); $e = 1 - [Math]::Pow(1 - $t, 3)
                $lw = 300; $lh = $lg.Height * $lw / $lg.Width
                $g.DrawImage($lg, [float]($W / 2 - $lw / 2), [float](-$lh + $e * ($lh + 14)), [float]$lw, [float]$lh)
            }
            if ($p -ge 14) {
                # "conoce a tus Glaggles": van entrando en fila
                Texto-Color $g 'KNOW YOUR GLAGGLES!' 'Arial Black' 20 ($W / 2 - 132) 112 (C 255 255 255) (C 20 20 20) 5
                for ($i = 0; $i -lt 7; $i++) {
                    $t2 = [Math]::Min(1.0, [Math]::Max(0.0, ($p - 16 - $i * 2.5) / 6.0)); if ($t2 -le 0) { continue }
                    $e2 = 1 - [Math]::Pow(1 - $t2, 3)
                    $tipo = $EnfosiTipos[$i]
                    $im = if ($tipo -eq 'gembo' -and $p -ge 44) { $script:enIn['gembo_enfosi.png'] } else { $script:enIn[$tipo] }
                    if (-not $im) { continue }
                    $ih = 120; $iw = $im.Width * $ih / $im.Height
                    $x = 48 + $i * 96 + (1 - $e2) * ($W + 100); $y = $H - $ih - 30 + [Math]::Abs([Math]::Sin(($p + $i) * 0.5)) * -6
                    $g.DrawImage($im, [float]($x + $sx), [float]($y + $sy), [float]$iw, [float]$ih)
                }
                # uno de ellos era un Enphosian: explosión negra
                if ($p -ge 44 -and $p -lt 52) {
                    $q = $p - 44; $cx = 48 + 3 * 96 + 30; $cy = $H - 90
                    for ($k = 0; $k -lt 3; $k++) { $rr = 20 + $q * 14 + $k * 16; $g.DrawEllipse((New-Object System.Drawing.Pen((ARGB ([int](220 - $q * 25)) 0 0 0), 10)), [float]($cx - $rr), [float]($cy - $rr), [float](2 * $rr), [float](2 * $rr)) }
                    Texto-Color $g '¡ENPHOSIAN!' 'Arial Black' 30 ($cx - 110) ($cy - 150) (C 20 20 20) (C 255 255 255) 6
                }
            }
        } elseif ($p -lt 66) {
            # el Ojo de Enphoso
            $g.Clear((C 0 0 0))
            $q = $p - 52; $al = [Math]::Min(1.0, $q / 6.0)
            $oj = $script:enIn['ojo.png']
            if ($oj) {
                $sz = 180 + $q * 8
                $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$al
                $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                $g.DrawImage($oj, (New-Object System.Drawing.Rectangle([int]($W / 2 - $sz / 2), [int]($H / 2 - $sz / 2 + 10), [int]$sz, [int]$sz)), 0, 0, $oj.Width, $oj.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
                $ia.Dispose()
            }
            $ti = $script:enIn['enphoso_titulo.png']
            if ($ti -and $q -ge 4) { $g.DrawImage($ti, [float]($W / 2 - 150), 14, 300, [float]($ti.Height * 300 / $ti.Width)) }
        } else {
            # primera oleada
            $im = $script:enIn['portada.jpg']; if ($im) { Imagen-Cubrir $g $im 0 0 $W $H 0.5 0.5 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 10 10 20))), 0, 0, $W, $H)
            $bn = $script:enIn['giggler_oleada.png']
            if ($bn) {
                $q = $p - 66; $e = if ($q -lt 4) { $q / 4.0 * 1.15 } elseif ($q -lt 7) { 1.15 - ($q - 4) / 3.0 * 0.15 } else { 1.0 }
                $bw = 420 * $e; $bh = $bn.Height * $bw / $bn.Width
                $g.DrawImage($bn, [float]($W / 2 - $bw / 2), [float]($H / 2 - $bh / 2 - 10), [float]$bw, [float]$bh)
            }
            Texto-Color $g 'OLEADA 1 / 7' 'Arial Black' 20 ($W / 2 - 80) ($H - 60) (C 255 255 255) (C 20 20 20) 5
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 2) { Sonido 'ding' }
        if ($p -eq 44) { Sonido 'revela' }
        if ($p -eq 52) { Sonido 'ojo' }
        if ($p -eq 66) { Sonido 'ola' }
        if ($p -gt 82) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 88 $pintar $alTick $final
}

# --- el templo de huesos, el ojo de la corona, el círculo ritual y la alianza del Cordero y la Cabra ---
function Transicion-Culto($final) {
    $script:tcFondo = Cargar-Img $script:skin.IntroImg
    $script:tcA = Cargar-Img $script:skin.Cartel; $script:tcB = Cargar-Img $script:skin.Cartel2
    $script:iRecursos = @($script:tcFondo, $script:tcA, $script:tcB)
    $script:tcLeyenda = '"Hay otro, viviendo más allá de tu reflejo... Ahora, joven dios. Te estaban esperando."'
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $g.Clear((C 10 4 6))
        # el templo aparece poco a poco desde la oscuridad, con un leve zoom
        if ($script:tcFondo) {
            $z = 1.12 - [Math]::Min(1.0, $p / 60.0) * 0.12
            $fw = $W * $z; $fh = $H * $z
            Imagen-Cubrir $g $script:tcFondo (($W - $fw) / 2) (($H - $fh) / 2) $fw $fh 0.5 0.4
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 - [Math]::Min(1.0, $p / 12.0) * 120), 10, 2, 4))), 0, 0, $W, $H)
        }
        $cx = $W / 2; $cy = 132
        # círculo ritual que se dibuja solo
        if ($p -ge 6) {
            $ang = [float][Math]::Min(360, ($p - 6) * 24)
            $pen = New-Object System.Drawing.Pen((C 220 40 54), 4)
            $g.DrawArc($pen, ($cx - 118), ($cy - 118), 236, 236, -90, $ang); $g.DrawArc($pen, ($cx - 104), ($cy - 104), 208, 208, 90, $ang)
            $pen.Dispose()
        }
        # el ojo rojo de la corona se abre
        $ab = [Math]::Min(1.0, $p / 10.0)
        if ($ab -gt 0) {
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 70 10 16))), [float]($cx - 64), [float]($cy - 38 * $ab), 128, [float](76 * $ab))
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 230 34 44))), [float]($cx - 24), [float]($cy - 24 * $ab), 48, [float](48 * $ab))
            $g.FillEllipse([System.Drawing.Brushes]::Black, [float]($cx - 6), [float]($cy - 18 * $ab), 12, [float](36 * $ab))
        }
        # el Cordero entra por la izquierda y la Cabra por la derecha
        if ($p -ge 14) {
            $t = [Math]::Min(1.0, ($p - 14) / 8.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            if ($script:tcA) { $g.DrawImage($script:tcA, [int](-220 + $e * 270), 34, 200, 188) }
            if ($script:tcB) { $g.DrawImage($script:tcB, [int]($W + 20 - $e * 270), 34, 200, 188) }
        }
        if ($p -ge 22) { Texto-Contorno $g 'EL CORDERO' 'Palatino Linotype' 30 40 214 (C 236 50 60) 7 }
        if ($p -ge 26) { Texto-Contorno $g 'LA CABRA' 'Palatino Linotype' 30 ($W - 210) 214 (C 186 126 236) 7 }
        if ($p -ge 30) { Texto-Contorno $g 'ALIANZA IMPÍA' 'Palatino Linotype' 26 ($cx - 112) 4 (C 238 226 200) 7 }
        if ($p -ge 34) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 0, 0, 0))), 0, ($H - 44), $W, 44)
            $n = [Math]::Min($script:tcLeyenda.Length, ($p - 34) * 4)
            $g.DrawString($script:tcLeyenda.Substring(0, $n), (FntP('Palatino Linotype', 10, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((C 210 170 240))), (New-Object System.Drawing.RectangleF(14, ($H - 40), ($W - 28), 38)))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'templo' }; if ($p -eq 4) { Sonido 'invocar' }; if ($p -eq 16) { Sonido 'balido' }; if ($p -eq 22) { Sonido 'enfado' }; if ($p -eq 30) { Sonido 'campana' }; if ($p -gt 62) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 68 $pintar $alTick $final
}

# --- la calle del pueblo: la radio avisa y las dos kaijus chocan ---
function Transicion-Kaiju($final) {
    $script:tkFondo = Cargar-Img $script:skin.IntroImg
    $script:tkA = Cargar-Img $script:skin.Cartel; $script:tkB = Cargar-Img $script:skin.Cartel2
    $script:iRecursos = @($script:tkFondo, $script:tkA, $script:tkB)
    $script:tkLeyenda = 'WMEW 99.9: "¡OH, DIOS! ¡EL LAGARTO DEL TRUENO SE ESTÁ PELEANDO CON LA TORTUGA ESPACIAL! ¡SALGAN DE AHÍ!"'
    $script:tkJp = Existe-Fuente 'Yu Gothic'
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $choque = 16
        $sx = 0; $sy = 0; if ($p -ge $choque -and $p -le $choque + 9) { $sx = $Rnd.Next(-9, 10); $sy = $Rnd.Next(-7, 8) }
        # la calle de la cinemática, temblando con el choque
        if ($script:tkFondo) { Imagen-Cubrir $g $script:tkFondo (-12 + $sx) (-8 + $sy) ($W + 24) ($H + 16) 0.5 0.6 } else { $g.Clear((C 60 50 50)) }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 140, 50, 20))), 0, 0, $W, $H)
        # antes del choque: aviso de la radio
        if ($p -lt $choque) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 0, 0, 0))), 0, 0, $W, $H)
            if (($p % 6) -lt 4) { Texto-Contorno $g '¡ÚLTIMA HORA!' 'EdmundMcMillen_INTLv4' 34 ($W / 2 - 110) 24 (C 255 60 50) 7 }
        }
        # las dos entran a la carrera y chocan en el centro
        $t = [Math]::Min(1.0, $p / [double]$choque); $e = $t * $t
        if ($script:tkA) { $g.DrawImage($script:tkA, [int](-260 + $e * ($W / 2 - 10) + $sx), [int](34 + $sy), 216, 276) }
        if ($script:tkB) { $g.DrawImage($script:tkB, [int]($W + 20 - $e * ($W / 2 + 30) + $sx), [int](78 + $sy), 268, 236) }
        if ($p -ge $choque -and $p -lt $choque + 3) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 250, 230))), 0, 0, $W, $H) }
        # nubes de polvo del choque
        if ($p -ge $choque -and $p -lt $choque + 20) {
            $q = $p - $choque
            for ($i = 0; $i -lt 10; $i++) { $ang = $i * 36 * [Math]::PI / 180; $d = 20 + $q * 9; $s = 30 + $q * 3; $al = [Math]::Max(0, 200 - $q * 10)
                $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 210, 200, 190))), [float]($W / 2 + [Math]::Cos($ang) * $d * 1.6 - $s / 2), [float](236 + [Math]::Sin($ang) * $d * 0.4 - $s / 2), [float]$s, [float]($s * 0.7)) }
        }
        if ($p -ge $choque + 2) {
            Texto-Contorno $g 'PYROPHINA' 'EdmundMcMillen_INTLv4' 46 16 6 (C 255 120 30) 8
            Texto-Contorno $g 'ZARATANA' 'EdmundMcMillen_INTLv4' 46 ($W - 20 - (Ancho-Texto 'ZARATANA' 'EdmundMcMillen_INTLv4' 46)) 6 (C 200 190 236) 8
            $tam = 84 + [Math]::Max(0, $choque + 8 - $p) * 7
            Texto-Contorno $g 'VS' 'EdmundMcMillen_INTLv4' $tam ($W / 2 - $tam * 0.42) (130 - $tam * 0.6) (C 255 214 60) 9
        }
        if ($p -ge $choque + 6 -and $script:tkJp) {
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString('ピロフィナ 対 ザラタナ', (FntP('Yu Gothic', 13, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 236 200))), (New-Object System.Drawing.RectangleF(0, 168, $W, 26)), $fmt)
        }
        if ($p -ge 30) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(225, 10, 8, 12))), 0, ($H - 54), $W, 54)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 200 40))), 0, ($H - 54), $W, 3)
            $n = [Math]::Min($script:tkLeyenda.Length, ($p - 30) * 5)
            $g.DrawString($script:tkLeyenda.Substring(0, $n), (FntP('TikaFont Adjusted', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 226 120))), (New-Object System.Drawing.RectangleF(14, ($H - 48), ($W - 28), 46)))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'radio' }; if ($p -eq 8) { Sonido 'pruge' }; if ($p -eq 12) { Sonido 'zruge' }; if ($p -eq 16) { Sonido 'pisoton' }; if ($p -gt 70) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 76 $pintar $alTick $final
}

# --- la polaroid de Averi cae entre hojas de otoño ---
function Transicion-Zorro($final) {
    $script:tzFoto = Cargar-Img 'skins\averi\feliz.png'
    $script:iRecursos = @($script:tzFoto)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'
        $g.Clear((C 255 240 220))
        # hojas de otoño cayendo
        $r = New-Object System.Random(4)
        for ($i = 0; $i -lt 18; $i++) {
            $x = $r.Next(0, $W); $v = 3 + $r.NextDouble() * 4; $y = (($r.Next(0, $H) + $p * $v) % ($H + 40)) - 20
            $col = @((C 230 128 56), (C 214 90 40), (C 240 180 70))[$i % 3]
            $st = $g.Save(); $g.TranslateTransform([float]($x + [Math]::Sin(($p + $i) / 4.0) * 10), [float]$y); $g.RotateTransform([float](($p * 8 + $i * 40) % 360))
            $g.FillEllipse((New-Object System.Drawing.SolidBrush($col)), -8, -4, 16, 8); $g.Restore($st)
        }
        # la foto cae y gira
        $t = [Math]::Min(1.0, $p / 12.0); $e = 1 - [Math]::Pow(1 - $t, 3)
        $st = $g.Save()
        $g.TranslateTransform([float]($W / 2), [float](-170 + $e * 310)); $g.RotateTransform([float](-20 + $e * 14))
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 60, 30, 10))), -104, -124, 220, 250)
        $g.FillRectangle([System.Drawing.Brushes]::White, -110, -130, 220, 250)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 226 190))), -96, -116, 192, 152)
        if ($script:tzFoto) { $g.DrawImage($script:tzFoto, -96, -116, 192, 152) }
        $g.DrawRectangle((New-Object System.Drawing.Pen((C 220 200 180), 1)), -110, -130, 220, 250)
        if ($p -ge 14) {
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
            $g.DrawString('¡Hola! Soy Averi', (FntP('Segoe Print', 13, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 110 60 30))), (New-Object System.Drawing.RectangleF(-108, 46, 216, 40)), $fmt)
        }
        $g.Restore($st)
        # el sándwich cae al lado, rebotando
        if ($p -ge 20) {
            $t2 = [Math]::Min(1.0, ($p - 20) / 8.0)
            $by = -40 + $t2 * 250 - [Math]::Abs([Math]::Sin($t2 * [Math]::PI * 2)) * 30 * (1 - $t2)
            Dibujar-Sandwich $g ($W / 2 + 170) $by 1.8
        }
        if ($p -ge 26) {
            for ($i = 0; $i -lt 5; $i++) { Dibujar-Corazon $g (($W / 2 - 200) + $i * 100) (240 - ($p - 26) * 5 - ($i % 2) * 24) 12 ([int][Math]::Max(0, 255 - ($p - 26) * 8)) }
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 8) { Sonido 'yip' }; if ($p -eq 26) { Sonido 'corazon' }; if ($p -eq 29) { Sonido 'comer' }; if ($p -gt 50) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 56 $pintar $alTick $final
}

# --- Sebastian: gateamos por la ventilación, se abre la rejilla y aparece su tienda ---
function Transicion-Vent($final) {
    $script:vFondo = Cargar-Img $script:skin.IntroImg
    $script:vTienda = Cargar-Img $script:skin.FondoImg
    $script:vSeb = Cargar-Img $script:skin.Gif
    $script:iRecursos = @($script:vFondo, $script:vTienda, $script:vSeb)
    $script:vLinea = 'SEBASTIAN: ' + (Azar $script:skin.Respiradero)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $cx = $W / 2; $cy = $H / 2
        if ($p -lt 34) {
            # dentro del conducto: avanzamos a gatas, con la linterna del casco
            $z = 1.0 + $p * 0.04; $bob = [Math]::Sin($p * 0.9) * 7
            if ($script:vFondo) { Imagen-Cubrir $g $script:vFondo (($W - $W * $z) / 2) ((($H - $H * $z) / 2) + $bob) ($W * $z) ($H * $z) 0.5 0.55 } else { $g.Clear((C 20 6 6)) }
            # paredes del conducto en perspectiva
            $m = New-Object System.Drawing.SolidBrush((ARGB 235 20 22 26)); $lin = New-Object System.Drawing.Pen((C 60 64 70), 3)
            $ix = 150 + ($p % 6) * 2; $iy = 70
            $g.FillPolygon($m, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, 0)), (New-Object System.Drawing.PointF($W, 0)), (New-Object System.Drawing.PointF(($W - $ix), $iy)), (New-Object System.Drawing.PointF($ix, $iy))))
            $g.FillPolygon($m, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, $H)), (New-Object System.Drawing.PointF($W, $H)), (New-Object System.Drawing.PointF(($W - $ix), ($H - $iy))), (New-Object System.Drawing.PointF($ix, ($H - $iy)))))
            foreach ($q in @(@(0, 0, $ix, $iy), @($W, 0, ($W - $ix), $iy), @(0, $H, $ix, ($H - $iy)), @($W, $H, ($W - $ix), ($H - $iy)))) { $g.DrawLine($lin, [float]$q[0], [float]$q[1], [float]$q[2], [float]$q[3]) }
            # remaches que pasan
            for ($i = 0; $i -lt 6; $i++) { $d = (($i * 0.17 + $p * 0.03) % 1.0); $rx = $ix * (1 - $d); $ry = $iy * (1 - $d); $g.DrawLine($lin, [float]$rx, [float]($H - $ry), [float]($W - $rx), [float]($H - $ry)) }
            $m.Dispose(); $lin.Dispose()
            # linterna: todo oscuro salvo un círculo de luz
            $mask = New-Object System.Drawing.Drawing2D.GraphicsPath; $mask.FillMode = 'Alternate'
            $mask.AddRectangle((New-Object System.Drawing.RectangleF(-10, -10, ($W + 20), ($H + 20)))); $mask.AddEllipse([float]($cx - 170), [float]($cy - 110 + $bob), 340, 220)
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 225 0 0 0))), $mask); $mask.Dispose()
            Texto-Contorno $g '*Gateando por la ventilación...*' 'Bahnschrift' 16 20 ($H - 34) (C 220 240 245) 3
        } else {
            # la tienda al otro lado
            if ($script:vTienda) { Imagen-Cubrir $g $script:vTienda 0 0 $W $H 0.0 0.45 } else { $g.Clear((C 8 10 14)) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 90 0 10 16))), 0, 0, $W, $H)
            # Sebastian se asoma desde la derecha
            if ($script:vSeb -and $p -ge 40) {
                $t = [Math]::Min(1.0, ($p - 40) / 10.0); $e = 1 - [Math]::Pow(1 - $t, 3)
                $sh = $H * 0.92; $sw = $script:vSeb.Width * $sh / $script:vSeb.Height
                $g.DrawImage($script:vSeb, [float]($W + 20 - $e * ($sw + 80)), [float]($H - $sh + 8 + [Math]::Sin($p / 3.0) * 3), [float]$sw, [float]$sh)
            }
            # la rejilla se abre hacia arriba
            if ($p -lt 46) {
                $sube = [Math]::Max(0, ($p - 36) * 34)
                $rej = New-Object System.Drawing.SolidBrush((C 50 54 60)); $bor = New-Object System.Drawing.Pen((C 22 24 28), 3)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 200 0 0 0))), 0, (0 - $sube), $W, $H)
                for ($y = 10; $y -lt $H; $y += 22) { $g.FillRectangle($rej, 30, ($y - $sube), ($W - 60), 12); $g.DrawRectangle($bor, 30, ($y - $sube), ($W - 60), 12) }
                $g.DrawRectangle((New-Object System.Drawing.Pen((C 70 74 80), 10)), 20, (5 - $sube), ($W - 40), ($H - 10))
                $rej.Dispose(); $bor.Dispose()
            }
            if ($p -ge 48) {
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 215 4 6 8))), 30, ($H - 52), ($W - 60), 40)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 190 200))), 30, ($H - 52), 4, 40)
                $n = [Math]::Min($script:vLinea.Length, ($p - 48) * 3)
                $g.DrawString($script:vLinea.Substring(0, $n), (FntP('Bahnschrift', 12, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 235 245 248))), 44, ($H - 46))
            }
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'conducto' }; if ($p -eq 35) { Sonido 'rejilla' }; if ($p -gt 70) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 76 $pintar $alTick $final
}

# --- Pursuer: la animación de presentación del juego y su logo ---
function Transicion-DoD($final) {
    $script:dGif = Cargar-Img $script:skin.IntroImg
    $script:dLogo = Cargar-Img $script:skin.TituloImg
    $script:iRecursos = @($script:dGif, $script:dLogo)
    $script:dInfo = if ($script:dGif) { Gif-Info $script:dGif } else { @{ N = 1; Del = @(100) } }
    $script:dDur = 0; foreach ($d in $script:dInfo.Del) { $script:dDur += $d }
    $script:dFin = [int]([Math]::Min(4200, $script:dDur) / 45)
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $g.Clear([System.Drawing.Color]::Black)
        if ($script:dGif) {
            # fotograma que toca según el tiempo
            $ms = [Math]::Min($p, $script:dFin) * 45; $acc = 0; $fr = 0
            for ($i = 0; $i -lt $script:dInfo.N; $i++) { $acc += $script:dInfo.Del[$i]; if ($acc -gt $ms) { $fr = $i; break }; $fr = $i }
            if ($script:dInfo.N -gt 1) { [void]$script:dGif.SelectActiveFrame((New-Object System.Drawing.Imaging.FrameDimension($script:dGif.FrameDimensionsList[0])), $fr) }
            Imagen-Cubrir $g $script:dGif 0 0 $W $H 0.5 0.5
        }
        # bandas de cine
        $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $W, 26); $g.FillRectangle([System.Drawing.Brushes]::Black, 0, ($H - 26), $W, 26)
        if ($p -ge $script:dFin) {
            $q = $p - $script:dFin
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(200, $q * 25), 0, 0, 0))), 0, 0, $W, $H)
            if ($script:dLogo) {
                $esc = [Math]::Max(1.0, 2.2 - $q * 0.25); $lw = 420 * $esc; $lh = $lw * $script:dLogo.Height / $script:dLogo.Width
                $sx = 0; if ($q -lt 6) { $sx = $Rnd.Next(-6, 7) }
                $g.DrawImage($script:dLogo, [float]($W / 2 - $lw / 2 + $sx), [float](80 - $lh / 2 + 30), [float]$lw, [float]$lh)
            }
            if ($q -ge 5) { Texto-Contorno $g '"AHH, FRESH MEAT!"' 'Arial Black' 30 ($W / 2 - (Ancho-Texto '"AHH, FRESH MEAT!"' 'Arial Black' 30) / 2) 200 (C 255 52 41) 6 }
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'intro' }; if ($p -eq $script:dFin) { Sonido 'aullido' }; if ($p -gt $script:dFin + 22) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay ($script:dFin + 28) $pintar $alTick $final
}

# --- Teto: montaje del videoclip de BIRDBRAIN (Teto bailando por la ciudad) y "¡Hiii~!" ---
function Transicion-Teto($final) {
    $script:tImg = Cargar-Img $script:skin.Gif
    $script:iRecursos = @($script:tImg)
    # bandada de palomas: cada una sale con un poco de retraso y a una altura distinta
    $r = New-Object System.Random 11
    $script:tBandada = @(for ($i = 0; $i -lt 16; $i++) { @{ D = $r.Next(0, 9); Y = 30 + $r.Next(0, 250); V = 46 + $r.Next(0, 18); E = 1.3 + $r.NextDouble() * 0.9; F = $r.NextDouble() * 6 } })
    $script:tPlumas = @(for ($i = 0; $i -lt 14; $i++) { @{ X = $r.Next(20, 740); D = 8 + $r.Next(0, 16); A = $r.Next(0, 360); V = 2 + $r.NextDouble() * 2 } })
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
        # fondo rosa con rayas que se mueven y franja de sus medias abajo
        Degradado $g 0 0 $W $H (C 253 228 232) (C 246 204 212) 90
        $ray = New-Object System.Drawing.Pen((ARGB 90 255 255 255), 16)
        for ($x = -$H - 60; $x -lt $W; $x += 46) { $g.DrawLine($ray, [float]($x + ($p * 2) % 46), 0, [float]($x + $H + ($p * 2) % 46), [float]$H) }
        $ray.Dispose()
        for ($x = 0; $x -lt $W; $x += 28) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 246 204 60))), $x, ($H - 16), 14, 16); $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 252 232 150))), ($x + 14), ($H - 16), 14, 16) }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 214 40 64))), 0, ($H - 20), $W, 4)
        # plumas cayendo después de la bandada
        if ($p -ge 10) {
            foreach ($f in $script:tPlumas) {
                $y = ($p - $f.D) * $f.V * 3 - 20; if ($y -lt -20 -or $y -gt $H) { continue }
                $st = $g.Save(); $g.TranslateTransform([float]($f.X + [Math]::Sin($p * 0.3 + $f.A) * 14), [float]$y); $g.RotateTransform([float]($f.A + $p * 6))
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 200 170 178 196))), -7, -2.5, 14, 5); $g.Restore($st)
            }
        }
        # Teto cae desde arriba y rebota al llegar
        $th = $H * 0.9; $tw = 0
        if ($script:tImg) {
            $tw = $script:tImg.Width * $th / $script:tImg.Height
            $t = [Math]::Max(0.0, [Math]::Min(1.0, ($p - 10) / 14.0))
            # rebote (easeOutBounce)
            if ($t -lt 1 / 2.75) { $e = 7.5625 * $t * $t } elseif ($t -lt 2 / 2.75) { $u = $t - 1.5 / 2.75; $e = 7.5625 * $u * $u + 0.75 } elseif ($t -lt 2.5 / 2.75) { $u = $t - 2.25 / 2.75; $e = 7.5625 * $u * $u + 0.9375 } else { $u = $t - 2.625 / 2.75; $e = 7.5625 * $u * $u + 0.984375 }
            $ty = ($H - $th - 12) - (1 - $e) * ($H + 40)
            $tx = $W * 0.66 - $tw / 2
            if ($p -ge 24) { $tx += [Math]::Sin($p * 0.35) * 5; $ty -= [Math]::Abs([Math]::Sin($p * 0.35)) * 6 }
            if ($p -ge 10) {
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB ([int](60 * $e)) 150 20 40))), [float]($W * 0.66 - $tw * 0.45), [float]($H - 26), [float]($tw * 0.9), 12)
                $g.DrawImage($script:tImg, [float]$tx, [float]$ty, [float]$tw, [float]$th)
            }
            # estrellitas al aterrizar
            if ($p -ge 24 -and $p -lt 34) {
                $q = $p - 24
                foreach ($k in 0..5) { $ang = $k * 60 * [Math]::PI / 180; $rr = 30 + $q * 9; $sx = $W * 0.66 + [Math]::Cos($ang) * $rr; $sy = $H - 30 + [Math]::Sin($ang) * $rr * 0.4
                    Texto-Contorno $g '★' 'Segoe UI Symbol' 16 $sx $sy (C 255 214 60) 3 ([int](255 * (1 - $q / 10.0))) }
            }
        }
        # su nombre entra desde la izquierda: letras rojas con borde blanco grueso
        if ($p -ge 18) {
            $t = [Math]::Min(1.0, ($p - 18) / 8.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            $nx = -420 + $e * 450
            foreach ($lin in @(@('KASANE', 58), @('TETO', 128))) {
                $path = New-Object System.Drawing.Drawing2D.GraphicsPath
                $path.AddString($lin[0], (Familia 'Arial Black'), 0, 64, (New-Object System.Drawing.PointF([float]$nx, [float]$lin[1])), [System.Drawing.StringFormat]::GenericDefault)
                $m = New-Object System.Drawing.Drawing2D.Matrix; $m.Translate(5, 6); $sombra = $path.Clone(); $sombra.Transform($m)
                $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 90 150 20 40))), $sombra)
                $pb = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 14); $pb.LineJoin = 'Round'; $g.DrawPath($pb, $path)
                $g.FillPath((New-Object System.Drawing.SolidBrush((C 214 40 64))), $path)
                $pb.Dispose(); $sombra.Dispose(); $path.Dispose()
            }
        }
        # pegatina amarilla de BIRDBRAIN
        if ($p -ge 30) {
            $q = $p - 30; $esc = if ($q -lt 3) { [Math]::Max(0.05, $q / 3.0 * 1.2) } elseif ($q -lt 6) { 1.2 - ($q - 3) / 3.0 * 0.2 } else { 1.0 }
            $st = $g.Save(); $g.TranslateTransform(150, 226); $g.RotateTransform(-6); $g.ScaleTransform([float]$esc, [float]$esc)
            $rp = Ruta-Redonda (-112) (-24) 224 48 24
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 255 255))), (Ruta-Redonda (-118) (-30) 236 60 30))
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 246 204 60))), $rp); $rp.Dispose()
            $tw2 = Ancho-Texto 'BIRDBRAIN' 'Arial Black' 26
            Texto-Contorno $g 'BIRDBRAIN' 'Arial Black' 26 (-$tw2 / 2) (-17) (C 176 24 48) 1
            $g.Restore($st)
        }
        # bocadillo "¡Hiii~!"
        if ($p -ge 26 -and $script:tImg) {
            $q = $p - 26; $esc = [Math]::Max(0.05, [Math]::Min(1.0, $q / 4.0))
            $bx = $W * 0.66 + $tw * 0.42; $by = 52
            $st = $g.Save(); $g.TranslateTransform([float]$bx, [float]$by); $g.ScaleTransform([float]$esc, [float]$esc)
            $rb = Ruta-Redonda 0 (-30) 150 60 26
            $g.FillPath([System.Drawing.Brushes]::White, $rb)
            $g.FillPolygon([System.Drawing.Brushes]::White, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(16, 18)), (New-Object System.Drawing.PointF(-14, 38)), (New-Object System.Drawing.PointF(36, 24))))
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 40 64), 3)), $rb); $rb.Dispose()
            Texto-Contorno $g '¡Hiii~!' 'Arial Black' 26 16 (-17) (C 214 40 64) 1
            $g.Restore($st)
        }
        # la bandada cruza por delante
        foreach ($b in $script:tBandada) {
            $x = -80 + ($p - $b.D) * $b.V
            if ($x -lt -80 -or $x -gt $W + 80) { continue }
            Dibujar-Pajaro $g $x ($b.Y + [Math]::Sin($p * 0.5 + $b.F) * 8) $b.E $true ($p * 1.1 + $b.F) 1
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'pio' }; if ($p -eq 6) { Sonido 'pio' }; if ($p -eq 25) { Sonido 'hiii' }; if ($p -eq 40) { Sonido 'teto' }; if ($p -gt 78) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 84 $pintar $alTick $final
}

# --- Kevin: se abre Paint, se dibuja la pizza, "DON'T TOUCH MY PIZZA" palabra a palabra, fuego y su cartel ---
function Transicion-Pizza($final) {
    $script:kvCanta = Cargar-Img 'skins\kevin\canta.gif'; $script:kvFuego = Cargar-Img 'skins\kevin\fuego.gif'; $script:kvFeliz = Cargar-Img 'skins\kevin\feliz_t.gif'
    $script:kvInfo = @{ C = (Gif-Info $script:kvCanta); F = (Gif-Info $script:kvFuego); H = (Gif-Info $script:kvFeliz) }
    $script:iRecursos = @($script:kvCanta, $script:kvFuego, $script:kvFeliz)
    $r = New-Object System.Random 8
    $script:kvLluvia = @(for ($i = 0; $i -lt 18; $i++) { @{ X = $r.Next(0, 760); D = $r.Next(0, 30); V = 6 + $r.Next(0, 6); A = $r.Next(0, 360) } })
    $script:pzMusica = $null
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $ms = $p * 45
        if ($p -lt 16) {
            # 1) escritorio de Windows: se abre Paint y un lápiz dibuja la pizza
            $g.Clear((C 0 128 128))
            $e = [Math]::Min(1.0, ($p + 1) / 6.0); $e = 1 - [Math]::Pow(1 - $e, 3)
            $pw = 520 * $e; $ph = 250 * $e; $px = $W / 2 - $pw / 2; $py = $H / 2 - $ph / 2
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 212 208 200))), [float]$px, [float]$py, [float]$pw, [float]$ph)
            if ($e -gt 0.9) {
                Degradado $g $px $py $pw 20 (C 10 36 106) (C 166 202 240) 0
                $g.DrawString('kevin.png - Paint', (FntP('Tahoma', 9, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, [float]($px + 6), [float]($py + 3))
                $g.FillRectangle([System.Drawing.Brushes]::White, [float]($px + 6), [float]($py + 26), [float]($pw - 12), [float]($ph - 32))
                $cx = $W / 2; $cy = $py + 26 + ($ph - 32) / 2; $rr = 70
                $ang = [Math]::Min(360, [Math]::Max(0, ($p - 5) * 40))
                if ($ang -ge 360) {
                    Dibujar-Pizza $g $cx $cy $rr 8 $false
                } elseif ($ang -gt 0) {
                    $g.DrawArc((New-Object System.Drawing.Pen((C 20 20 20), 4)), [float]($cx - $rr), [float]($cy - $rr), [float](2 * $rr), [float](2 * $rr), -90, [float]$ang)
                    # el lápiz
                    $an = (-90 + $ang) * [Math]::PI / 180; $lx = $cx + [Math]::Cos($an) * $rr; $ly = $cy + [Math]::Sin($an) * $rr
                    $st = $g.Save(); $g.TranslateTransform([float]$lx, [float]$ly); $g.RotateTransform(-40)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 200 40))), 0, -5, 46, 10); $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 140 160))), 46, -5, 10, 10)
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 240 210 160))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(0, -5)), (New-Object System.Drawing.PointF(0, 5)), (New-Object System.Drawing.PointF(-12, 0))))
                    $g.Restore($st)
                }
                $g.DrawString('nyanwolf presenta...', (FntP('Comic Sans MS', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 30 100 240))), [float]($px + 14), [float]($py + 30))
            }
        } elseif ($p -lt 48) {
            # 2) Kevin canta y las palabras caen de golpe: DON'T / TOUCH / MY / PIZZA
            $g.Clear([System.Drawing.Color]::White)
            foreach ($t in $script:kvLluvia) { $y = ($p - 16 - $t.D) * $t.V - 30; if ($y -gt -30 -and $y -lt $H + 30) { Dibujar-Trozo $g $t.X $y 26 ($t.A + $p * 9) } }
            if ($script:kvCanta) {
                Gif-Frame $script:kvCanta $script:kvInfo.C $ms
                $kh = $H * 0.98; $kw = $script:kvCanta.Width * $kh / $script:kvCanta.Height
                $g.DrawImage($script:kvCanta, [float]($W - $kw + 30), [float]($H - $kh), [float]$kw, [float]$kh)
            }
            $pal = @(@("DON'T", 18, (C 70 200 40)), @('TOUCH', 24, (C 30 100 240)), @('MY', 30, (C 255 110 200)), @('PIZZA', 36, (C 230 40 40)))
            $sx = 0; $sy = 0
            if ($p -lt 42 -and (($p - 18) % 6) -lt 2 -and $p -ge 18) { $sx = $Rnd.Next(-8, 9); $sy = $Rnd.Next(-6, 7) }
            for ($i = 0; $i -lt 4; $i++) {
                $q = $p - $pal[$i][1]; if ($q -lt 0) { continue }
                $esc = if ($q -lt 3) { 2.2 - $q * 0.4 } else { 1.0 }
                $st = $g.Save(); $g.TranslateTransform([float](40 + $sx + $i * 6), [float](30 + $i * 66 + $sy)); $g.RotateTransform(-4); $g.ScaleTransform([float]$esc, [float]$esc)
                Texto-Color $g $pal[$i][0] 'Impact' 56 0 0 $pal[$i][2] (C 20 20 20) 10
                $g.Restore($st)
            }
        } elseif ($p -lt 76) {
            # 3) ¡FUEGO! (lo que pasa si la tocas)
            $g.Clear((C 40 0 0))
            if ($script:kvFuego) {
                Gif-Frame $script:kvFuego $script:kvInfo.F (($p - 48) * 45)
                $s = [Math]::Max($W / $script:kvFuego.Width, $H / $script:kvFuego.Height) * 1.04
                $fw = $script:kvFuego.Width * $s; $fh = $script:kvFuego.Height * $s
                $g.DrawImage($script:kvFuego, [float]($W / 2 - $fw / 2 + $Rnd.Next(-4, 5)), [float]($H / 2 - $fh / 2 + $Rnd.Next(-4, 5)), [float]$fw, [float]$fh)
            }
            if ($p % 4 -lt 3) {
                $txt = '¡¡NO TOQUES MI PIZZA!!'; $tw = Ancho-Texto $txt 'Impact' 44
                Texto-Color $g $txt 'Impact' 44 ($W / 2 - $tw / 2 + $Rnd.Next(-3, 4)) ($H - 74) (C 255 230 60) (C 20 0 0) 9
            }
        } else {
            # 4) cartel final: arcoíris de 2010, Kevin feliz y su nombre letra a letra
            $g.Clear([System.Drawing.Color]::White)
            $arco = @((C 255 40 40), (C 255 150 30), (C 255 225 50), (C 90 210 80), (C 40 140 255), (C 140 70 220))
            for ($i = 0; $i -lt $arco.Count; $i++) {
                $pts = New-Object System.Collections.ArrayList
                for ($x = 0; $x -le $W; $x += 20) { [void]$pts.Add((New-Object System.Drawing.PointF([float]$x, [float](150 + $i * 16 + [Math]::Sin($x / 60.0 + $p * 0.5) * 8)))) }
                $g.DrawLines((New-Object System.Drawing.Pen($arco[$i], 16)), [System.Drawing.PointF[]]$pts.ToArray())
            }
            foreach ($t in $script:kvLluvia) { $a = $t.A + $p * 6; $rx = $W * 0.68 + [Math]::Cos(($t.A + $p * 5) * [Math]::PI / 180) * (150 + $t.D * 3); $ry = $H * 0.5 + [Math]::Sin(($t.A + $p * 5) * [Math]::PI / 180) * (90 + $t.D); Dibujar-Trozo $g $rx $ry 22 $a }
            if ($script:kvFeliz) {
                Gif-Frame $script:kvFeliz $script:kvInfo.H (($p - 76) * 45)
                $kh = $H * 0.95; $kw = $script:kvFeliz.Width * $kh / $script:kvFeliz.Height
                $kx = $W * 0.68 - $kw / 2
                $g.DrawImage($script:kvFeliz, [float]$kx, [float]($H - $kh), [float]$kw, [float]$kh)
            }
            $letras = 'KEVIN'.ToCharArray(); $cols = @((C 70 200 40), (C 30 100 240), (C 255 110 200), (C 255 206 84), (C 230 40 40))
            for ($i = 0; $i -lt $letras.Count; $i++) {
                $q = $p - 78 - $i * 2; if ($q -lt 0) { continue }
                $by = 40 - [Math]::Max(0, 30 - $q * 8) - [Math]::Abs([Math]::Sin(($p + $i) * 0.6)) * 6
                Texto-Color $g ([string]$letras[$i]) 'Comic Sans MS' 72 (30 + $i * 62) $by $cols[$i] (C 20 20 20) 10
            }
            if ($p -ge 90) { Texto-Color $g "don't touch my pizza  ·  nyanwolf" 'Comic Sans MS' 16 34 ($H - 56) (C 20 20 20) (C 255 255 255) 6 }
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) {
            if ($script:aj.Sonido) { $n = $script:reproductores.Count; Sonido 'polka'; if ($script:reproductores.Count -gt $n -or $script:reproductores.Count -ge 12) { $script:pzMusica = $script:reproductores[$script:reproductores.Count - 1] } }
        }
        if ($p -eq 18 -or $p -eq 24 -or $p -eq 30 -or $p -eq 36) { Sonido 'nam' }
        if ($p -eq 48) { Sonido 'grito' }
        if ($p -eq 76) { Sonido 'ding' }
        # la música se apaga poco a poco al final
        if ($p -ge 100 -and $script:pzMusica) { try { $script:pzMusica.Volume = $script:pzMusica.Volume * 0.72; if ($p -ge 111) { $script:pzMusica.Stop(); $script:pzMusica = $null } } catch {} }
        if ($p -gt 106) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 112 $pintar $alTick $final
}

# pastillas redondeadas y miniaturas de vídeo (estilo YouTube)
function Yt-Pastilla($g, $x, $y, $w, $h, $fondo, $texto, $colTexto, $tam) {
    $r = Ruta-Redonda $x $y $w $h ($h / 2)
    $g.FillPath((New-Object System.Drawing.SolidBrush($fondo)), $r); $r.Dispose()
    if ($texto) {
        $f = FntP('Segoe UI Symbol', $tam, [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($texto, $f).Width
        $g.DrawString($texto, $f, (New-Object System.Drawing.SolidBrush($colTexto)), [float]($x + $w / 2 - $tw / 2), [float]($y + $h / 2 - $f.Height / 2))
    }
}
# miniatura de vídeo: el GIF recortado, esquinas redondas y la duración abajo a la derecha
function Yt-Miniatura($g, $img, $inf, $ms, $x, $y, $w, $h, $dur) {
    if ($img) {
        Gif-Frame $img $inf $ms
        $st = $g.Save(); $rr = Ruta-Redonda $x $y $w $h 8; $g.SetClip($rr)
        $g.DrawImage($img, [float]$x, [float]$y, [float]$w, [float]$h)
        $g.Restore($st); $rr.Dispose()
    } else { $g.FillPath((New-Object System.Drawing.SolidBrush((C 39 39 39))), (Ruta-Redonda $x $y $w $h 8)) }
    if ($dur) {
        $f = FntP('Segoe UI', 6.5, [System.Drawing.FontStyle]::Bold); $tw = $g.MeasureString($dur, $f).Width
        $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 210 0 0 0))), (Ruta-Redonda ($x + $w - $tw - 6) ($y + $h - 15) ($tw + 2) 12 3))
        $g.DrawString($dur, $f, [System.Drawing.Brushes]::White, [float]($x + $w - $tw - 5), [float]($y + $h - 15))
    }
}

# --- Kennyoung: el cielo del atardecer, su silueta entra con la guitarra y, con un destello, su nombre ---
# Imágenes de su vídeo: el cielo vacío (intro_cielo), la silueta (intro_silueta) y él en color (intro_kenny).
# Va sincronizada con el reloj. Momentos (en milisegundos):
$KyIntro = @{ Silueta = 1300; Acorde = 1750; Destello = 3300; Nombre = 3500; Lema = 4000; Fin = 6300 }
function Transicion-Punk($final) {
    $script:kiCielo = Cargar-Img 'skins\kennyoung\intro_cielo.jpg'; $script:kiSil = Cargar-Img 'skins\kennyoung\intro_silueta.png'; $script:kiKenny = Cargar-Img 'skins\kennyoung\intro_kenny.png'
    $script:iRecursos = @($script:kiCielo, $script:kiSil, $script:kiKenny)
    $script:kyT0 = 0; $script:kyHechos = @{}
    $r = New-Object System.Random 3
    $script:kiEstrellas = @(for ($i = 0; $i -lt 40; $i++) { @{ X = $r.NextDouble(); Y = $r.NextDouble() * 0.5; F = $r.NextDouble() * 6; S = 1 + $r.NextDouble() * 1.6 } })
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $T = $KyIntro
        $ms = if ($script:kyT0 -gt 0) { [Environment]::TickCount - $script:kyT0 } else { 0 }
        # 1) el cielo del atardecer, moviéndose despacio, con estrellas que parpadean
        $z = 1.08 - [Math]::Min(1.0, $ms / 6000.0) * 0.06
        if ($script:kiCielo) { [void](Dibujar-Cubriendo $g $script:kiCielo $W $H $z 0.3 0.5) }
        foreach ($e in $script:kiEstrellas) {
            $al = [int](110 + 110 * [Math]::Sin($ms / 260.0 + $e.F))
            $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Max(0, $al), 255, 240, 250))), [float]($e.X * $W), [float]($e.Y * $H), [float]$e.S, [float]$e.S)
        }
        # el personaje: misma caja para la silueta y para él en color
        $kh = $H * 0.93; $kx = $W * 0.73
        if ($ms -ge $T.Silueta -and $ms -lt $T.Destello -and $script:kiSil) {
            # 2) su silueta entra desde la derecha y se balancea con la guitarra
            $tq = [Math]::Min(1.0, ($ms - $T.Silueta) / 450.0); $e = 1 - [Math]::Pow(1 - $tq, 3)
            $sw = $script:kiSil.Width * $kh / $script:kiSil.Height
            $bx = $kx - $sw / 2 + (1 - $e) * ($W * 0.5); $by = $H - $kh + [Math]::Sin($ms / 300.0) * 2
            # brillo rosa detrás al tocar el acorde
            if ($ms -ge $T.Acorde) {
                $q = [Math]::Min(1.0, ($ms - $T.Acorde) / 500.0)
                $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse([float]($kx - $sw * 0.7), [float]($H * 0.1), [float]($sw * 1.4), [float]($H * 1.0))
                $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pg.CenterColor = [System.Drawing.Color]::FromArgb([int](140 * (1 - $q * 0.5)), 255, 150, 200); $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 150, 200))
                $g.FillPath($pg, $gp); $pg.Dispose(); $gp.Dispose()
            }
            $g.DrawImage($script:kiSil, [float]$bx, [float]$by, [float]$sw, [float]$kh)
        }
        if ($ms -ge $T.Nombre -and $script:kiKenny) {
            # 3) él en color y su nombre, que entra deslizando, inclinado
            $q = [Math]::Min(1.0, ($ms - $T.Nombre) / 350.0); $e = 1 - [Math]::Pow(1 - $q, 3)
            $cw = $script:kiKenny.Width * $kh / $script:kiKenny.Height
            $g.DrawImage($script:kiKenny, [float]($kx - $cw / 2 + (1 - $e) * 30), [float]($H - $kh + [Math]::Sin($ms / 300.0) * 2), [float]$cw, [float]$kh)
            $nx = 40 - (1 - $e) * 520; $ny = $H * 0.36
            $st = $g.Save(); $g.TranslateTransform([float]$nx, [float]$ny)
            $sesgo = New-Object System.Drawing.Drawing2D.Matrix(1, 0, -0.22, 1, 0, 0); $g.MultiplyTransform($sesgo)
            # brillo rosa y letras blancas, como en su vídeo
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddString('KENNYOUNG', (Familia 'Arial Black'), 0, 58, (New-Object System.Drawing.PointF(0, 0)), [System.Drawing.StringFormat]::GenericDefault)
            foreach ($gr in @(@(22, 40), @(14, 70), @(7, 110))) { $pn = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($gr[1], 255, 110, 170), [float]$gr[0]); $pn.LineJoin = 'Round'; $g.DrawPath($pn, $path); $pn.Dispose() }
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 244 246))), $path); $path.Dispose()
            if ($ms -ge $T.Lema) {
                $lema = 'MUSIC, ART, VIDEO'; $n = [Math]::Min($lema.Length, [int](($ms - $T.Lema) / 45))
                $g.DrawString($lema.Substring(0, $n), (FntP('Arial', 12, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic))), (New-Object System.Drawing.SolidBrush((C 255 236 240))), 70, 74)
            }
            $g.Restore($st)
        }
        # el destello blanco entre la silueta y él en color
        if ($ms -ge $T.Destello -and $ms -lt $T.Nombre + 400) {
            $q = ($ms - $T.Destello) / [double]($T.Nombre + 400 - $T.Destello); $al = if ($q -lt 0.35) { $q / 0.35 } else { 1 - ($q - 0.35) / 0.65 }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * [Math]::Max(0, [Math]::Min(1, $al))), 255, 255, 255))), 0, 0, $W, $H)
        }
        # al principio sale del negro
        if ($ms -lt 600) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * (1 - $ms / 600.0)), 0, 0, 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $T = $KyIntro
        if ($p -eq 1) { $script:kyT0 = [Environment]::TickCount }
        $ms = [Environment]::TickCount - $script:kyT0
        foreach ($ev in @(@($T.Acorde, 'acorde'), @($T.Destello, 'riff'))) {
            if ($ms -ge $ev[0] -and -not $script:kyHechos.ContainsKey($ev[1])) { $script:kyHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $T.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- Evil Scary: la pantalla de la RONDA ESPECIAL del juego ("SPECIAL ROUND! ???" -> "EVIL SCARY"),
#     luego "IT IS EVIL AND SCARY" y la bola negra botando hacia la cámara hasta el susto ---
# Va sincronizada con el reloj. Momentos (en milisegundos):
$EsIntro = @{ Ruleta = 400; Revela = 2600; Mensaje = 5200; Bote1 = 6600; Bote2 = 7400; Bote3 = 8200; Susto = 9000; Fin = 10300 }
# el cartel de "SPECIAL ROUND!" de Die of Death: caja oscura con borde rojo y tres líneas de texto
function Dibujar-Ronda($g, $W, $H, $grande, $abajo, $colGrande, $esc) {
    $bw = 470 * $esc; $bh = 150 * $esc; $bx = $W / 2 - $bw / 2; $by = $H / 2 - $bh / 2 - 10
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 235 24 18 18))), [float]$bx, [float]$by, [float]$bw, [float]$bh)
    $g.DrawRectangle((New-Object System.Drawing.Pen((C 170 20 30), [float](3 * $esc))), [float]$bx, [float]$by, [float]$bw, [float]$bh)
    $fm = New-Object System.Drawing.StringFormat; $fm.Alignment = 'Center'
    $g.DrawString('SPECIAL ROUND!', (FntP('Arial', [float](17 * $esc), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 120 20 26))), (New-Object System.Drawing.RectangleF([float]$bx, [float]($by + 8 * $esc), [float]$bw, [float](30 * $esc))), $fm)
    $g.DrawString($grande, (FntP('Arial', [float](34 * $esc), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($colGrande)), (New-Object System.Drawing.RectangleF([float]$bx, [float]($by + 38 * $esc), [float]$bw, [float](60 * $esc))), $fm)
    $g.DrawString($abajo, (FntP('Arial', [float](10.5 * $esc), [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 200 200 200))), (New-Object System.Drawing.RectangleF([float]$bx, [float]($by + 104 * $esc), [float]$bw, [float](40 * $esc))), $fm)
}
function Transicion-Evil($final) {
    $k = $script:skin
    $script:eiFondo = Cargar-Img $k.FondoImg; $script:eiSusto = Cargar-Img $k.Susto; $script:eiEvil = Cargar-Img $k.Gif
    $script:iRecursos = @($script:eiFondo, $script:eiSusto, $script:eiEvil)
    $script:eiT0 = 0; $script:eiHechos = @{}
    $script:eiModos = @('???', 'ONE BOUNCE', 'GUNSLINGER', 'DOUBLE TROUBLE', 'DIENATION', '???', 'GOLF', 'FRYBOMBER')
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'; $g.TextRenderingHint = 'AntiAlias'
        $T = $EsIntro
        $ms = if ($script:eiT0 -gt 0) { [Environment]::TickCount - $script:eiT0 } else { 0 }
        $g.Clear([System.Drawing.Color]::Black)
        if ($ms -lt $T.Mensaje) {
            # 1) el mapa de fondo, muy oscuro, y el cartel de la ronda especial
            if ($script:eiFondo) {
                [void](Dibujar-Cubriendo $g $script:eiFondo $W $H 1.05 0.5 0.5)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 150 0 0 0))), 0, 0, $W, $H)
            }
            $esc = [Math]::Min(1.0, 0.6 + $ms / 600.0)
            if ($ms -lt $T.Revela) {
                # "???" y una ruleta de modos que va frenando
                $txt = if ($ms -lt $T.Ruleta) { '???' } else { $i = [int](($ms - $T.Ruleta) / (70 + ($ms - $T.Ruleta) / 18.0)); $script:eiModos[$i % $script:eiModos.Count] }
                Dibujar-Ronda $g $W $H $txt 'What will it be?' (C 170 170 170) $esc
            } else {
                $q = [Math]::Min(1.0, ($ms - $T.Revela) / 250.0); $e2 = 1.25 - 0.25 * $q
                Dibujar-Ronda $g $W $H 'EVIL SCARY' 'The Evil Scary will eradicate anything in its path.' (C 150 20 28) $e2
            }
        } elseif ($ms -lt $T.Susto) {
            # 2) negro. "IT IS EVIL AND SCARY" y la bola negra botando hacia la cámara
            if ($script:eiFondo) { [void](Dibujar-Cubriendo $g $script:eiFondo $W $H 1.1 0.5 0.5); $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 200 0 0 0))), 0, 0, $W, $H) }
            $q = [Math]::Min(1.0, ($ms - $T.Mensaje) / 400.0)
            $fm = New-Object System.Drawing.StringFormat; $fm.Alignment = 'Center'
            $g.DrawString('IT IS EVIL AND SCARY', (FntP('Arial', 26, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * $q), 220, 30, 40))), (New-Object System.Drawing.RectangleF(0, 30, $W, 50)), $fm)
            if ($script:eiEvil -and $ms -ge $T.Bote1) {
                $n = if ($ms -ge $T.Bote3) { 3 } elseif ($ms -ge $T.Bote2) { 2 } else { 1 }
                $t0 = @($T.Bote1, $T.Bote2, $T.Bote3)[$n - 1]
                $salto = [Math]::Sin([Math]::Min(1.0, ($ms - $t0) / 250.0) * [Math]::PI) * 18
                $ew = @(140, 260, 470)[$n - 1]; $eh = $ew * $script:eiEvil.Height / $script:eiEvil.Width
                $g.DrawImage($script:eiEvil, [float]($W / 2 - $ew / 2), [float]($H * 0.62 + $n * 25 - $eh - $salto), [float]$ew, [float]$eh)
            }
        } else {
            # 3) el susto (cara roja a toda pantalla, que se apaga)
            if ($script:eiSusto) {
                $q = [Math]::Min(1.0, ($ms - $T.Susto) / 1200.0)
                [void](Dibujar-Cubriendo $g $script:eiSusto $W $H (1.0 + $q * 0.2) 0.5 0.5)
                $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * $q), 0, 0, 0))), 0, 0, $W, $H)
            }
        }
    }
    $alTick = {
        param($ov, $p)
        $T = $EsIntro
        if ($p -eq 1) { $script:eiT0 = [Environment]::TickCount }
        $ms = [Environment]::TickCount - $script:eiT0
        foreach ($ev in @(@($T.Revela, 'violin'), @($T.Mensaje, 'susto'), @($T.Bote1, 'lejos'), @($T.Bote2, 'medio'), @($T.Bote3, 'cerca'), @($T.Susto, 'grito'))) {
            if ($ms -ge $ev[0] -and -not $script:eiHechos.ContainsKey($ev[1])) { $script:eiHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $T.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- Soft Fuzzy Man: los 11 primeros segundos de la animación de Aimkid (con su audio) y, de transición,
#     la cámara se mete en la espiral rosa y la niebla lo tapa todo; el panel sale de la niebla ---
# Los fotogramas están en skins\softfuzzy\intro (001.jpg, 002.jpg...), a 18 por segundo. Momentos (en milisegundos):
$SfIntro = @{ Niebla = 10300; Fin = 12300 }
function Transicion-Fuzzy($final) {
    $script:fiImg = $null; $script:fiIdx = -1; $script:fiT0 = 0; $script:iRecursos = @()
    Sf-Reset
    $pintar = {
        param($g, $W, $H, $p)
        $g.InterpolationMode = 'HighQualityBilinear'; $g.SmoothingMode = 'AntiAlias'
        $k = $script:skin; $T = $SfIntro
        $ms = if ($script:fiT0 -gt 0) { [Environment]::TickCount - $script:fiT0 } else { 0 }
        $g.Clear((C 82 31 135))
        # el fotograma que toca según el reloj (se carga solo el que hace falta)
        $idx = [Math]::Min($k.IntroFotos - 1, [int][Math]::Floor($ms * $k.IntroFps / 1000.0))
        if ($idx -ne $script:fiIdx) {
            $nueva = Cargar-Img ('{0}\{1:000}.jpg' -f $k.IntroCarpeta, ($idx + 1))
            if ($nueva) { if ($script:fiImg) { $script:fiImg.Dispose() }; $script:fiImg = $nueva; $script:fiIdx = $idx; $script:iRecursos = @($nueva) }
        }
        if ($script:fiImg) {
            # el vídeo entero a lo alto (con bandas moradas a los lados); al final, zoom hacia la espiral
            $z = 1.0; if ($ms -gt $T.Niebla) { $z = 1.0 + [Math]::Pow(($ms - $T.Niebla) / ($T.Fin - $T.Niebla), 2) * 2.5 }
            $ih = $H * $z; $iw = $ih * $script:fiImg.Width / $script:fiImg.Height
            $g.DrawImage($script:fiImg, [float]($W / 2 - $iw / 2), [float]($H / 2 - $ih / 2), [float]$iw, [float]$ih)
        }
        if ($ms -gt $T.Niebla) {
            # la niebla rosa lo tapa todo
            $q = [Math]::Min(1.0, ($ms - $T.Niebla) / ($T.Fin - $T.Niebla - 200))
            Pintar-Niebla $g 0 $W $H (1.6 * $q)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * $q * $q), 255, 186, 244))), 0, 0, $W, $H)
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 1) { $script:fiT0 = [Environment]::TickCount; Sonido 'intro' }
        $ms = [Environment]::TickCount - $script:fiT0
        if ($ms -gt $SfIntro.Fin -and $script:iPaso -lt $script:iTotal - 1) { $script:iPaso = $script:iTotal - 1 }
        # en el último paso (también si se salta) el panel queda tapado de niebla y se va despejando
        if ($script:iPaso -ge $script:iTotal - 1) { Sf-Niebla 1800 255 }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

# --- Nanachi: descenso al Abismo capa a capa, la entrada del escondite y Nanachi entre los hilos del campo de fuerza ---
# Va sincronizada con el reloj. Momentos (en milisegundos):
$NnIntro = @{ Caliz = 0; Capa4 = 2600; Entrada = 4700; Nanachi = 5600; Nombre = 6400; Fin = 8800 }
$NnCapas = @(@('1ª capa', 'Borde del Abismo', '0 – 1.350 m'), @('2ª capa', 'Bosque de la Tentación', '1.350 – 2.600 m'), @('3ª capa', 'Gran Falla', '2.600 – 7.000 m'), @('4ª capa', 'Cáliz de los Gigantes', '7.000 – 12.000 m'))
function Transicion-Nanachi($final) {
    $k = $script:skin
    $script:niCaliz = Cargar-Img 'skins\nanachi\intro_caliz.jpg'; $script:niCapa = Cargar-Img 'skins\nanachi\intro_capa4b.jpg'
    $script:niEntrada = Cargar-Img 'skins\nanachi\intro_entrada.jpg'; $script:niNana = Cargar-Img 'skins\nanachi\nanachi.png'
    $script:iRecursos = @($script:niCaliz, $script:niCapa, $script:niEntrada, $script:niNana)
    $script:niT0 = 0; $script:niHechos = @{}
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $T = $NnIntro
        $ms = if ($script:niT0 -gt 0) { [Environment]::TickCount - $script:niT0 } else { 0 }
        $g.Clear((C 8 14 10))
        if ($ms -lt $T.Capa4 -and $script:niCaliz) {
            # 1) bajamos por el Abismo: la imagen alta se recorre de arriba abajo y van pasando las capas
            $q = $ms / [double]$T.Capa4
            [void](Dibujar-Cubriendo $g $script:niCaliz $W $H 1.0 0.5 $q)
            $i = [Math]::Min(3, [int]($q * 4))
            $c = $NnCapas[$i]; $al = [int](255 * [Math]::Min(1.0, (($q * 4) % 1.0) * 4))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int]($al * 0.55)) 0 0 0))), 0, ($H - 70), $W, 70)
            Texto-Color $g $c[0] 'Georgia' 22 30 ($H - 66) (ARGB $al 252 240 214) (ARGB $al 0 0 0) 4
            $g.DrawString("$($c[1])  ·  $($c[2])", (FntP('Georgia', 11, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((ARGB $al 236 170 190))), 32, [float]($H - 32))
            # profundidad que va bajando
            $m = [int]($q * 7100)
            Texto-Color $g ('{0:N0} m' -f $m) 'Consolas' 18 ($W - 150) 20 (C 252 240 214) (C 0 0 0) 4
        } elseif ($ms -lt $T.Entrada -and $script:niCapa) {
            # 2) la 4ª capa: cálices gigantes y cascadas, con zoom lento
            $z = 1.0 + ($ms - $T.Capa4) / 9000.0
            [void](Dibujar-Cubriendo $g $script:niCapa $W $H $z 0.5 0.5)
            Texto-Color $g '7.100 m' 'Consolas' 18 ($W - 150) 20 (C 252 240 214) (C 0 0 0) 4
            Texto-Color $g '4ª capa · Cáliz de los Gigantes' 'Georgia' 18 30 ($H - 50) (C 252 240 214) (C 0 0 0) 4
        } elseif ($script:niEntrada) {
            # 3) la entrada del escondite, con su luz verde; los hilos del campo de fuerza aparecen
            $z = 1.0 + ($ms - $T.Entrada) / 7000.0
            [void](Dibujar-Cubriendo $g $script:niEntrada $W $H $z 0.5 0.5)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 70 0 0 0))), 0, 0, $W, $H)
            Dibujar-Campo $g 0 0 $W $H ([int][Math]::Min(120.0, ($ms - $T.Entrada) / 8.0))
            if ($ms -ge $T.Nanachi -and $script:niNana) {
                # Nanachi sube desde abajo y se queda
                $q = [Math]::Min(1.0, ($ms - $T.Nanachi) / 500.0); $e = 1 - [Math]::Pow(1 - $q, 3)
                $nh = $H * 0.95; $nw = $script:niNana.Width * $nh / $script:niNana.Height
                $g.DrawImage($script:niNana, [float]($W * 0.74 - $nw / 2), [float]($H - $nh + (1 - $e) * $nh * 0.8 + [Math]::Sin($ms / 400.0) * 2), [float]$nw, [float]$nh)
            }
            if ($ms -ge $T.Nombre) {
                $q = [Math]::Min(1.0, ($ms - $T.Nombre) / 400.0); $e = 1 - [Math]::Pow(1 - $q, 3)
                Texto-Color $g 'NANACHI' 'Georgia' 60 (40 - (1 - $e) * 300) 70 (C 252 240 214) (C 60 40 30) 10
                if ($ms -ge $T.Nombre + 500) { Texto-Color $g 'Made in Abyss' 'Georgia' 18 46 150 (C 236 170 190) (C 30 20 14) 5 }
                if ($ms -ge $T.Nombre + 1000) {
                    $txt = 'Nnaa. ...¿qué?'; $n = [Math]::Min($txt.Length, [int](($ms - $T.Nombre - 1000) / 90))
                    Texto-Color $g $txt.Substring(0, $n) 'Segoe Print' 26 50 186 (C 255 255 255) (C 120 70 80) 6
                }
            }
        }
        # sale del negro al principio
        if ($ms -lt 600) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](255 * (1 - $ms / 600.0)), 0, 0, 0))), 0, 0, $W, $H) }
    }
    $alTick = {
        param($ov, $p)
        $T = $NnIntro
        if ($p -eq 1) { $script:niT0 = [Environment]::TickCount }
        $ms = [Environment]::TickCount - $script:niT0
        foreach ($ev in @(@(0, 'viento'), @(300, 'silbato'), @($T.Nanachi, 'brillo'))) {
            if ($ms -ge $ev[0] -and -not $script:niHechos.ContainsKey($ev[1])) { $script:niHechos[$ev[1]] = $true; Sonido $ev[1] }
        }
        if ($ms -gt $T.Fin -and $script:iPaso -lt $script:iTotal - 7) { $script:iPaso = $script:iTotal - 7 }
        if ($p -gt $script:iTotal - 7) { $ov.Top -= [int]($ov.Height / 5) }
    }
    Intro-Overlay 400 $pintar $alTick $final
}

[System.Windows.Forms.Application]::add_ThreadException({
    try {
        switch ($script:skin.Estilo) {
            'hacker' { Glitch 8 '> error interceptado. todo bajo control.' }
            'tele' { Corte-Senal 10; Decir '¡Bzzzt! Interferencias... ¡ya está!' }
            'mew' { Decir '*Guillotina se ha comido un error. Lo digiere.*' }
            'lobo' { Decir 'Incidente registrado y contenido, Manager.' 'serio' }
            'mlg' { Decir 'Lag. Ha sido lag. Yo no fallo.' }
            'oeste' { Decir '*Le dispara al error. Problema resuelto.*' }
            'culto' { Decir 'Cabra: Algo se ha roto. Ha sido el Cordero.' }
            'kaiju' { Decir 'WMEW 99.9: Una kaiju ha pisado un error. Ya no existe.' }
            'zorro' { Decir '¡Ups! Algo se ha roto... ¡No he sido yo! ...Bueno, quizá.' 'serio' }
            'pressure' { Decir 'Algo se ha roto. Lo pondré en oferta.' }
            'dod' { Decir '*Destroza el error de un zarpazo.*' }
            'pizza' { Decir '*Algo se ha roto. Kevin le da un mordisco al error.* Arreglado. Sabía a queso azul. PUAJ.' }
            'enfosi' { Decir 'Algo se ha roto. ¿Habrá sido un Enphosian? *Lo mira con desconfianza.*' }
            'punk' { Decir 'Algo se ha roto. No era la guitarra, por una vez. *Toca un acorde para arreglarlo.*' }
            'gran' { Decir 'Algo se ha roto. Un fallo del protocolo. Lo anoto y seguimos.' }
            'abismo' { Decir 'Algo se ha roto. Nnaa. Le pongo una venda y listo.' }
            'evil' { Decir 'ALGO SE HA ROTO. *Evil Scary bota encima del error. El error desaparece. Tú casi también.*' }
            'niebla' { Decir 'Algo se ha roto. Yo no he sido: no puedo tocar nada. *Se pone transparente por si acaso.*' }
            default { Decir 'Algo se ha roto. No he sido yo. Creo.' }
        }
    } catch {}
})

# ================= LÓGICA =================
function Nuevo-Boton($texto, $x, $y, $w, $h) {
    $k = $script:skin
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texto
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $k.BtnBorde
    $b.FlatAppearance.BorderSize = $k.BtnBordeAncho
    $b.FlatAppearance.MouseOverBackColor = $k.BtnHover
    $b.FlatAppearance.MouseDownBackColor = $k.BtnPress
    if ($k.Paleta) { $b.BackColor = $k.Paleta[$script:bi % $k.Paleta.Count]; $script:bi++ } else { $b.BackColor = $k.BtnFondo }
    $b.ForeColor = $k.BtnTexto
    $estilo = if ($k.Fuente -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
    $tam = if ($k.Fuente -in @('Impact', 'Bahnschrift', 'Georgia')) { 9.5 } elseif ($k.Fuente -eq 'Arial Black') { 8.5 } else { 10 }
    $b.Font = Fnt($k.Fuente, $tam, $estilo)
    $b.Cursor = 'Hand'
    $b.TabStop = $false
    # algunas skins dibujan sus propios botones (madera, papel, telarañas...)
    $b.Add_Paint({ Pintar-Boton $_.Graphics $this })
    $b.Add_MouseEnter({ $this.Invalidate() }); $b.Add_MouseLeave({ $this.Invalidate() })
    return $b
}

function Ruta-Redonda($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc([float]$x, [float]$y, [float]$r, [float]$r, 180, 90); $p.AddArc([float]($x + $w - $r), [float]$y, [float]$r, [float]$r, 270, 90)
    $p.AddArc([float]($x + $w - $r), [float]($y + $h - $r), [float]$r, [float]$r, 0, 90); $p.AddArc([float]$x, [float]($y + $h - $r), [float]$r, [float]$r, 90, 90)
    $p.CloseFigure(); return $p
}

function Dibujar-Telarana($g, $W, $H) {
    $g.SmoothingMode = 'AntiAlias'
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 255, 255, 255))), 0, 0, $W, $H)
    $seda = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(215, 245, 245, 250), [float](1.2 * $script:K))
    $cx = $W / 2; $cy = $H / 2; $n = 10
    $rad = @(); for ($i = 0; $i -lt $n; $i++) { $a = 2 * [Math]::PI * $i / $n; $rad += , @([Math]::Cos($a), [Math]::Sin($a)) }
    foreach ($d in $rad) { $g.DrawLine($seda, [float]$cx, [float]$cy, [float]($cx + $d[0] * $W * 0.62), [float]($cy + $d[1] * $H * 0.9)) }
    foreach ($f in @(0.25, 0.5, 0.78)) {
        $pts = New-Object 'System.Drawing.PointF[]' $n
        for ($i = 0; $i -lt $n; $i++) { $pts[$i] = New-Object System.Drawing.PointF([float]($cx + $rad[$i][0] * $W * 0.62 * $f), [float]($cy + $rad[$i][1] * $H * 0.9 * $f)) }
        $g.DrawPolygon($seda, $pts)
    }
    $seda.Dispose()
}

function Pintar-Boton($g, $b) {
    $k = $script:skin; $W = $b.Width; $H = $b.Height; $Z = $script:K
    $hover = $b.ClientRectangle.Contains($b.PointToClient([System.Windows.Forms.Cursor]::Position))
    $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    $rect = New-Object System.Drawing.RectangleF(0, 0, $W, $H)
    $enBarra = ($b.Parent -eq $form) -and ($b.Top -lt [int](52 * $Z))
    switch ($k.Estilo) {
        'oeste' {
            # cartel de madera con vetas y clavos
            $g.SmoothingMode = 'AntiAlias'
            $c1 = if ($hover) { (C 190 126 66) } else { (C 150 96 50) }; $c2 = if ($hover) { (C 150 96 48) } else { (C 110 66 32) }
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), $c1, $c2, 90)
            $g.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
            $veta = New-Object System.Drawing.Pen((C 92 56 28), [float](1 * $Z))
            foreach ($f in @(0.26, 0.5, 0.76)) { $y = [float]($H * $f); $g.DrawBezier($veta, [float](4 * $Z), $y, [float]($W * 0.3), [float]($y - 3 * $Z), [float]($W * 0.62), [float]($y + 3 * $Z), [float]($W - 4 * $Z), $y) }
            $veta.Dispose()
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 48 26 10), [float](2 * $Z))), [float]$Z, [float]$Z, [float]($W - 2 * $Z), [float]($H - 2 * $Z))
            foreach ($nx in @((7 * $Z), ($W - 7 * $Z))) {
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 60 58 62))), [float]($nx - 2.5 * $Z), [float]($H / 2 - 2.5 * $Z), [float](5 * $Z), [float](5 * $Z))
                $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 170 170 175))), [float]($nx - 1.2 * $Z), [float]($H / 2 - 1.6 * $Z), [float](1.6 * $Z), [float](1.6 * $Z))
            }
            $sombra = New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1.5 * $Z), $W, $H)
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 50 28 12))), $sombra, $fmt)
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 252 238 205))), $rect, $fmt)
        }
        'mew' {
            # tarjeta de papel con borde de tinta irregular y sombra
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear((C 46 33 40))
            $r = New-Object System.Random([Math]::Abs($b.Text.GetHashCode()) % 9973)
            $j = { [float](($r.NextDouble() - 0.5) * 3 * $Z) }
            $x1 = 2 * $Z; $y1 = 2 * $Z; $x2 = $W - 5 * $Z; $y2 = $H - 5 * $Z
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x1 + (& $j)), [float]($y1 + (& $j)))), (New-Object System.Drawing.PointF([float]($x2 + (& $j)), [float]($y1 + (& $j)))), (New-Object System.Drawing.PointF([float]($x2 + (& $j)), [float]($y2 + (& $j)))), (New-Object System.Drawing.PointF([float]($x1 + (& $j)), [float]($y2 + (& $j)))))
            $somb = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF(($_.X + 3 * $Z), ($_.Y + 3 * $Z)) })
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 18 10 12))), $somb)
            $papel = if ($hover) { (C 228 96 72) } else { (C 246 236 210) }
            $g.FillPolygon((New-Object System.Drawing.SolidBrush($papel)), $pts)
            $tinta = New-Object System.Drawing.Pen((C 20 14 16), [float](2.5 * $Z)); $tinta.LineJoin = 'Round'
            $g.DrawPolygon($tinta, $pts); $tinta.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 25 18 20))), (New-Object System.Drawing.RectangleF(0, 0, ($W - 3 * $Z), ($H - 3 * $Z))), $fmt)
        }
        'culto' {
            # losa del templo con borde rojo y rombos dorados en las esquinas
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 14 8 10) } else { (C 30 16 20) }))
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 3 * $Z) ($H - 3 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 120 20 30) } else { (C 40 26 30) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 150 24 36), [float](2 * $Z))), $r); $r.Dispose()
            $oro = New-Object System.Drawing.SolidBrush((C 214 170 60)); $d = 3 * $Z
            foreach ($q in @(@((5 * $Z), ($H / 2)), @(($W - 6 * $Z), ($H / 2)))) { $g.FillPolygon($oro, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$q[0], [float]($q[1] - $d))), (New-Object System.Drawing.PointF([float]($q[0] + $d), [float]$q[1])), (New-Object System.Drawing.PointF([float]$q[0], [float]($q[1] + $d))), (New-Object System.Drawing.PointF([float]($q[0] - $d), [float]$q[1])))) }
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 238 226 200))), $rect, $fmt)
        }
        'kaiju' {
            # cartel de película de monstruos: negro con borde naranja
            $g.Clear($(if ($enBarra) { (C 12 8 10) } else { (C 26 16 34) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 230 90 20) } else { (C 26 18 24) }))), 0, 0, $W, $H)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 200, 60))), [float](2 * $Z), [float](2 * $Z), [float]($W - 4 * $Z), [float](3 * $Z))
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 255 120 30), [float](2 * $Z))), [float]$Z, [float]$Z, [float]($W - 2 * $Z), [float]($H - 2 * $Z))
            $sombra = New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1.5 * $Z), $W, $H)
            $g.DrawString($b.Text, $b.Font, [System.Drawing.Brushes]::Black, $sombra, $fmt)
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 250 230) } else { (C 255 236 200) }))), $rect, $fmt)
        }
        'femta' {
            # pegatina blanca con contorno negro y sombra roja; al pasar el ratón se pone roja
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 0 0 0) } else { (C 10 6 8) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float](3 * $Z), [float](3 * $Z), [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 230 20 40) } else { (C 255 255 255) }))), [float]$Z, [float]$Z, [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, [float](2 * $Z))), [float]$Z, [float]$Z, [float]($W - 4 * $Z), [float]($H - 4 * $Z))
            $g.DrawString($b.Text, $b.Font, $(if ($hover) { [System.Drawing.Brushes]::White } else { [System.Drawing.Brushes]::Black }), $rect, $fmt)
        }
        'punk' {
            # botón crema con borde marrón (como el bocadillo); al pasar el ratón, verde de pegatina
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 96 74 68) } else { (C 255 246 236) }))
            if ($script:bmpEscena) {
                # el trozo de fondo que queda detrás del botón (para que las esquinas redondas no se vean cuadradas)
                $pf = $form.PointToClient($b.PointToScreen([System.Drawing.Point]::Empty))
                $g.DrawImage($script:bmpEscena, (New-Object System.Drawing.Rectangle((-$pf.X), (-$pf.Y), $script:bmpEscena.Width, $script:bmpEscena.Height)))
            }
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 3 * $Z) ($H - 3 * $Z) ([Math]::Min(($H - 3 * $Z) / 2, 12 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 110 235 140) } else { (C 255 248 240) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 70 50 45), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 70 50 45))), $rect, $fmt)
        }
        'pizza' {
            # botón blanco dibujado con rotulador y sombra rosa; al pasar el ratón se pone verde Kevin
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 70 200 40) } else { (C 255 255 255) }))
            $sh = Ruta-Redonda (3 * $Z) (3 * $Z) ($W - 5 * $Z) ($H - 5 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($enBarra) { (C 30 100 240) } else { (C 255 110 200) }))), $sh); $sh.Dispose()
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 5 * $Z) ($H - 5 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 70 200 40) } else { (C 255 255 255) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 20 20 20), [float](2 * $Z))), $r); $r.Dispose()
            $rt = New-Object System.Drawing.RectangleF(0, 0, ($W - 3 * $Z), ($H - 3 * $Z))
            if ($hover) {
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 20 20 20))), (New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1.5 * $Z), ($W - 3 * $Z), ($H - 3 * $Z))), $fmt)
                $g.DrawString($b.Text, $b.Font, [System.Drawing.Brushes]::White, $rt, $fmt)
            } else { $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 20 20 20))), $rt, $fmt) }
        }
        'pop' {
            # pastilla morada con borde de neón cian; al pasar el ratón, rosa
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 70 20 90) } else { (C 26 12 48) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 12 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 92 190) } else { (C 44 20 78) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen($(if ($hover) { (C 255 255 255) } else { (C 90 230 250) }), [float](2 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((ARGB 120 255 92 190))), (New-Object System.Drawing.RectangleF([float](1.5 * $Z), [float](1 * $Z), $W, $H)), $fmt)
            $g.DrawString($b.Text, $b.Font, [System.Drawing.Brushes]::White, $rect, $fmt)
        }
        'gran' {
            # botón de laboratorio: oscuro con borde verde; al pasar el ratón se llena de verde
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 0 0 0) } else { (C 9 12 10) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 5 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 32 208 44) } else { (C 14 22 16) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 32 208 44), [float](1.6 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 8 10 9) } else { (C 200 255 205) }))), $rect, $fmt)
        }
        'evil' {
            # botón oscuro con borde rojo; al pasar el ratón, rojo sangre
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 0 0 0) } else { (C 8 4 6) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 4 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 150 14 24) } else { (C 22 10 12) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 170 20 30), [float](1.6 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 236 220 220))), $rect, $fmt)
        }
        'niebla' {
            # botón morado con borde rosa neón; al pasar el ratón, rosa como él
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 58 22 98) } else { (C 46 18 80) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 9 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 160 245) } else { (C 66 26 112) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 255 90 230), [float](1.6 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 40 10 60) } else { (C 255 225 250) }))), $rect, $fmt)
        }
        'abismo' {
            # botón de pergamino con borde de cuero; al pasar el ratón, rosa como su ropa
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 78 56 40) } else { (C 32 44 32) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 7 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 236 170 190) } elseif ($enBarra) { (C 64 46 32) } else { (C 246 236 212) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen($(if ($enBarra) { (C 236 170 190) } else { (C 92 70 52) }), [float](2 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($enBarra -and -not $hover) { (C 252 240 214) } else { (C 60 44 34) }))), $rect, $fmt)
        }
        'enfosi' {
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 252 200 55) } else { (C 34 38 54) }))
            $rr = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 9 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 214 60) } else { (C 255 255 255) }))), $rr)
            $g.DrawPath((New-Object System.Drawing.Pen((C 25 25 25), [float](2 * $Z))), $rr); $rr.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 25 25 25))), $rect, $fmt)
        }
        'teto' {
            # botón blanco y rojo; al pasar el ratón se pone amarillo como sus medias
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 214 40 64) } else { (C 252 236 238) }))
            $r = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 14 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 232 140) } else { (C 255 250 248) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 214 40 64), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 176 24 48))), $rect, $fmt)
        }
        'zorro' {
            # pastilla crema con borde naranja
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 230 128 56) } else { (C 255 243 226) }))
            $r = Ruta-Redonda (1.5 * $Z) (1.5 * $Z) ($W - 4 * $Z) ($H - 4 * $Z) ([Math]::Min($H - 4 * $Z, 22 * $Z))
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 214 170) } else { (C 255 250 240) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 230 128 56), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 110 60 30))), $rect, $fmt)
        }
        'pressure' {
            # placa metálica con esquinas ámbar; en la tienda muestra el objeto y su precio
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 8 10 14) } else { (C 12 16 20) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 36 96 104) } else { (C 20 26 32) }))), 0, 0, $W, $H)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 70 190 200), [float]$Z)), [float]($Z / 2), [float]($Z / 2), [float]($W - $Z), [float]($H - $Z))
            $esq = New-Object System.Drawing.Pen((C 255 190 70), [float](2 * $Z)); $L = 6 * $Z
            $g.DrawLines($esq, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$Z, [float]($Z + $L))), (New-Object System.Drawing.PointF([float]$Z, [float]$Z)), (New-Object System.Drawing.PointF([float]($Z + $L), [float]$Z))))
            $g.DrawLines($esq, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($W - $Z), [float]($H - $Z - $L))), (New-Object System.Drawing.PointF([float]($W - $Z), [float]($H - $Z))), (New-Object System.Drawing.PointF([float]($W - $Z - $L), [float]($H - $Z)))))
            $esq.Dispose()
            if ($b.Tag -is [hashtable] -and $b.Tag.Tienda) {
                $it = $b.Tag.Tienda; $s = $H - 8 * $Z
                Dibujar-Objeto $g $it.Id (4 * $Z) (4 * $Z) $s
                $fi = New-Object System.Drawing.StringFormat; $fi.LineAlignment = 'Center'
                $g.DrawString($it.Nombre, $b.Font, (New-Object System.Drawing.SolidBrush((C 220 240 245))), (New-Object System.Drawing.RectangleF([float]($s + 7 * $Z), 0, [float]($W - $s - 34 * $Z), [float]$H)), $fi)
                $fd = New-Object System.Drawing.StringFormat; $fd.Alignment = 'Far'; $fd.LineAlignment = 'Center'
                $g.DrawString("$($it.Precio)", $b.Font, (New-Object System.Drawing.SolidBrush((C 255 190 70))), (New-Object System.Drawing.RectangleF(0, 0, [float]($W - 6 * $Z), [float]$H)), $fd)
            } else {
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 255 255) } else { (C 220 240 245) }))), $rect, $fmt)
            }
        }
        'dod' {
            # botón negro con borde verde, como la interfaz de Die of Death
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 4 8 6) } else { (C 6 12 8) }))
            $r = Ruta-Redonda (1 * $Z) (1 * $Z) ($W - 3 * $Z) ($H - 3 * $Z) (8 * $Z)
            $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 0 110 78) } else { (C 8 14 10) }))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 0 160 110), [float](2 * $Z))), $r); $r.Dispose()
            $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush($(if ($hover) { (C 255 255 255) } else { (C 200 255 230) }))), $rect, $fmt)
        }
    }
    if ($script:telarana -and $b.Tag -is [hashtable] -and [object]::ReferenceEquals($b.Tag, $script:telarana)) { Dibujar-Telarana $g $W $H }
}

function Hover-Color($b) {
    $col = $b.ForeColor; $hov = $script:skin.BtnTextoHover
    $b.Add_MouseEnter({ $this.ForeColor = $hov }.GetNewClosure())
    $b.Add_MouseLeave({ $this.ForeColor = $col }.GetNewClosure())
}

function Lanzar($item) {
    $k = $script:skin
    # Velvet: si el botón está atrapado en una telaraña, el primer clic la rompe
    if ($script:telarana -and [object]::ReferenceEquals($script:telarana, $item)) {
        $script:telarana = $null; $telTimer.Stop()
        foreach ($c in $script:grid.Controls) { $c.Invalidate() }
        Decir '*Rompes la telaraña.* Qué fuerte eres, cielo... vuelve a pulsar para abrirlo.'
        return
    }
    $linea = Azar $k.PorApp[$item.Nombre]
    if (-not $linea) { $linea = Azar $k.Frases }
    try {
        # %USERPROFILE% y parecidos se cambian por la carpeta de verdad (para botones de carpetas)
        Start-Process ([Environment]::ExpandEnvironmentVariables($item.Abrir)) -ErrorAction Stop
        switch ($k.Estilo) {
            'hacker' { Glitch 3 $linea }
            'tele' { Corte-Senal 4; Decir $linea }
            'mew' { Guillotina-Ataque 'come' $linea }
            'lobo' {
                $antes = $script:energia
                $script:energia = [Math]::Min(100, $script:energia + 10)
                $form.Invalidate()
                if ($antes -lt 100 -and $script:energia -ge 100) { Decir 'Cuota de energía completada. Excelente trabajo, Manager.' 'abiertos' }
                else { Decir $linea 'abiertos' }
            }
            'mlg' {
                $script:lanzadas++; $script:hitsTotal++
                Nuevo-Hit ([int]($Rnd.Next(30, 160) * $script:K)) ([int]($Rnd.Next(25, 125) * $script:K))
                if ($script:lanzadas % 4 -eq 0) { $script:dew++; Sonido 'dew'; Decir '¡DO THE DEW! *Velocidad aumentada.*' }
                else { Sonido 'disparo'; Decir $linea }
                $form.Invalidate()
            }
            'oeste' {
                if (Zodiac-Disparo) { Decir $linea } else { Decir '*click* ...*click* ¡Sin balas! Haz clic en Zodiac para recargar.' }
            }
            'culto' {
                # cada app es un seguidor nuevo; cada 5, un ritual
                $script:seguidores++; $script:fe = [Math]::Min(100, $script:fe + 6)
                if ($script:seguidores % 5 -eq 0) { Culto-Ritual } else { if ($Rnd.Next(2) -eq 0) { Sonido 'balido' }; Decir $linea; $form.Invalidate() }
            }
            'kaiju' { Kaiju-Ataque (@('P', 'Z')[$Rnd.Next(2)]) $linea }
            'pressure' { $script:investigacion += 2; Flotante '+2' 150 262 (C 120 230 240) 22 'Bahnschrift'; Decir $linea; $form.Invalidate() }
            'dod' { Pursuer-Ataque 'presa' $linea }
            'femta' {
                $script:tkFichas++; Sonido 'moneda'
                Flotante '+1 TOKEN' 180 262 (C 255 60 70) 20 'Consolas'
                if ($script:tkFichas % 10 -eq 0) { Token-Breakcore } else { Decir $linea }
                $form.Invalidate()
            }
            'pop' {
                if (Tetra-Mensaje) { Decir $linea } else { Decir "$linea (Te ha llegado un mensaje, pero estás en No molestar.)" }
                $form.Invalidate()
            }
            'enfosi' {
                # cada app trae un Glaggle a la estatua
                if ($script:ef -and -not $script:ef.W -and -not $script:ef.Banner -and -not $script:ef.Cartel) { Enfosi-Llega }
                else { if ($script:ef) { $script:ef.Cola++ }; Decir $linea }
            }
            'teto' {
                Teto-Pajaro
                $nv = @{ 'YouTube' = 'youtube'; 'Word' = 'word'; 'Excel' = 'excel'; 'Teams' = 'teams' }[$item.Nombre]
                if ($nv) { Sonido $nv } else { Sonido (Azar @('okay', 'letsgo', 'yay')) }
                $script:tetoVozT = [Environment]::TickCount
                Decir $linea
            }
            'pizza' {
                # con las apps de oficina, a veces se sienta a trabajar... y se cae de la silla
                if ($item.Nombre -in @('Word', 'Excel', 'PowerPoint', 'Access', 'Outlook', 'OneNote', 'Publisher', 'Teams') -and $Rnd.Next(3) -eq 0) {
                    Actor-Pose 'V' 'trabajo' 3100; Decir (Azar $k.Trabajo)
                } else { Kevin-Comer $linea }
            }
            'punk' { Ky-App $linea }
            'gran' { Gran-Dosis $linea }
            'abismo' { Nn-App $linea }
            'evil' { Es-App $linea }
            'niebla' { Sf-App $linea }
            'zorro' {
                $script:antojo = [Math]::Min(100, $script:antojo + 5); $form.Invalidate()
                if ($Rnd.Next(4) -eq 0) { Sonido 'ups'; Decir (Azar $k.Torpe) 'serio' } else { Decir $linea 'abiertos' }
            }
            'gunsaw' {
                if ($k.Hambre) {
                    $script:hambre = [Math]::Min(100, $script:hambre + 6); $form.Invalidate()
                    if ($script:hambre -ge 100) { Decir "DUNE COMER $($item.Nombre.ToUpper()). ÑAM. (tranquilo, se ha abierto igual)" } else { Decir $linea }
                } else { Decir $linea }
            }
            default { Decir $linea }
        }
    } catch {
        if ($item.Web) {
            Start-Process ([Environment]::ExpandEnvironmentVariables($item.Web))
            switch ($k.Estilo) {
                'hacker' { Decir "> $($item.Nombre) not found. redirecting to web..." }
                'tele' { Decir "¡No tengo $($item.Nombre) en la tele! ¡Te pongo la versión web!" }
                'mew' { Decir "*No encuentra $($item.Nombre). Se come la versión web.*" }
                'lobo' { Decir "$($item.Nombre) no está instalado. Redirigiendo a la versión web, Manager." 'serio' }
                'mlg' { Decir "No tienes $($item.Nombre). Te abro la web. Rápido como un hitscan." }
                'oeste' { Decir "*No encuentra $($item.Nombre) en el saloon. Abre la versión web.*" }
                'culto' { Decir "Cabra: No tienes $($item.Nombre). Te abro la web. El culto proveerá." }
                'kaiju' { Decir "WMEW 99.9: $($item.Nombre) ha sido aplastado. Abriendo la versión web entre los escombros." }
                'zorro' { Decir "¡No encuentro $($item.Nombre)! ...¡Te abro la web! ¿Vale? Vale." 'serio' }
                'femta' { Sonido 'glitch'; Decir "$($item.Nombre) N0T F0UND. Te abro la web. A todo volumen." }
                'pop' { Decir "No tienes $($item.Nombre). Te abro la web. Tranqui." }
                'enfosi' { Decir "No tienes $($item.Nombre). Te abro la web. Mientras, vigila la estatua." }
                'teto' { Sonido 'oops'; Decir "¡No encuentro $($item.Nombre)! Te abro la web. ...¿qué estábamos buscando?" }
                'pizza' { Decir "¡No tienes $($item.Nombre)! Te abro la web. Mientras carga, me como un trozo. *ÑAM.*" }
                'punk' { Decir "No tienes $($item.Nombre). Te abro la web. Como cuando no tienes la guitarra y tocas con la de un amigo." }
                'gran' { Decir "No tiene $($item.Nombre). Le abro la web. Anote el fallo en su expediente." }
                'abismo' { Decir "No tienes $($item.Nombre). Te abro la web. Es como mandar un globo de correo: llega igual, pero más tarde." }
                'evil' { Decir "$($item.Nombre.ToUpper()) NO ESTÁ INSTALADO. ABRIENDO LA WEB. *Evil Scary te mira cargarla. No parpadea. No tiene ojos.*" }
                'niebla' { Decir "No tienes $($item.Nombre). Te abro la web. Internet es como yo: está en todas partes y no se puede tocar." }
                default { Decir "$($item.Nombre) no está instalado. Te abro la web. De nada." }
            }
        } else {
            switch ($k.Estilo) {
                'hacker' { Glitch 6 "> ERROR: $($item.Nombre) resisted the hack" }
                'tele' { Corte-Senal 10; Decir "¡Bzzzt! No encuentro el canal $($item.Nombre)..." }
                'mew' { Decir "*Busca $($item.Nombre) por todas partes. No está. Se enfada.*" }
                'lobo' { Decir "Error: $($item.Nombre) no localizado. Revise la instalación, Manager." 'serio' }
                'mlg' { Cara 'clic' 2500; Decir "Fallé el tiro: $($item.Nombre) no existe. Eso nunca pasa. Nunca." }
                'oeste' { Cara 'vacio' 1800; Decir "¡$($item.Nombre) ha huido del pueblo! Cobarde." }
                'culto' { Decir "Cordero: *Busca $($item.Nombre) por todo el templo. No está.* · Cabra: Hereje." }
                'kaiju' { Decir "WMEW 99.9: No hay rastro de $($item.Nombre). Probablemente aplastado." }
                'zorro' { Sonido 'ups'; Decir "¡No encuentro $($item.Nombre) por ningún lado! ¡Lo siento muchísimo!" 'serio' }
                'femta' { Sonido 'glitch'; $a = $script:actores['K']; if ($a) { $a.Temblor = 10 }; Decir "ERR0R: $($item.Nombre) no existe. *Token le pega un cabezazo a la pantalla. Sigue sin existir.*" }
                'pop' { Decir "No encuentro $($item.Nombre). Como esos amigos de 2020. Se fue y ya." }
                'enfosi' { Sonido 'buzzer'; Decir "¡$($item.Nombre) no aparece! Como la cara de un Enphosian disfrazado." }
                'teto' { Sonido 'uhoh'; Decir "¡$($item.Nombre) se ha ido volando! Como un pájaro. Igual vuelve." }
                'pizza' { Actor-Pose 'V' 'sudor' 2000; Decir "¡No encuentro $($item.Nombre)! ...¿Alguien lo ha tocado? ¿Como a mi pizza? *Suda.*" }
                'punk' { Ky-Video 'piensa' 2500; Decir "No encuentro $($item.Nombre). Como mis canciones sin terminar: igual algún día aparece." }
                'gran' { Gran-Tapar 3000; Decir "$($item.Nombre) no está. Un sujeto que se escapa del estudio. No pasará dos veces." }
                'abismo' { Nn-Cara 'nnaa' 2000; Decir "No encuentro $($item.Nombre). Se habrá caído al Abismo. Lo que cae ahí no vuelve." }
                'evil' { Es-Reset; Es-Rebote 3.0; Decir "NO SE ENCUENTRA $($item.Nombre.ToUpper()). *Se lo ha comido. O lo ha atravesado. Da igual.*" }
                'niebla' { Actor-Pose 'F' 'cara' 1500; Decir "No encuentro $($item.Nombre). Se habrá vuelto niebla. Me pasa a mí también." }
                default { Decir "No encuentro $($item.Nombre). Igual nunca existió." }
            }
        }
    }
}

function Mostrar-Pagina {
    $grid.Controls.Clear()
    $script:bi = 0
    $hacker = $script:skin.Estilo -in @('hacker', 'lobo', 'mlg', 'gunsaw')
    # el texto de la página vuelve a su tamaño normal (el menú Skins lo hace más pequeño)
    $script:lblPag.Font = Fnt($script:lblPag.Font.FontFamily.Name, 10, $script:lblPag.Font.Style)
    if ($script:modoSkins) {
        # una página por grupo (ver $GruposSkins): nombre de la skin y, debajo, de dónde viene
        $ps = Paginas-Skins
        if ($script:pagSkins -lt 0 -or $script:pagSkins -ge $ps.Count) { $script:pagSkins = 0 }
        $pg = $ps[$script:pagSkins]; $i = 0
        foreach ($it in $pg.Items) {
            $n = $it.Nombre
            $txt = if ($n -eq $script:skinNombre) { "[ $n ]" } else { $n }
            if ($it.Origen) { $txt = "$txt`n$($it.Origen)" }
            $b = Nuevo-Boton $txt (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
            $b.Font = Fnt($b.Font.FontFamily.Name, $(if ($n.Length -gt 12) { 7 } else { 7.5 }), $b.Font.Style)
            $b.Tag = $n
            $b.Add_Click({ Aplicar-Skin $this.Tag })
            # al pasar el ratón, el asistente opina de esa skin
            $b.Add_MouseEnter({ if (-not (Ocupado)) { Decir (Opinion $this.Tag) 'abiertos' } })
            if ($hacker) { Hover-Color $b }
            Escalar $b; $grid.Controls.Add($b); $i++
        }
        $parte = if ($pg.Partes -gt 1) { " $($pg.Parte)" } else { '' }
        $script:lblPag.Font = Fnt($script:lblPag.Font.FontFamily.Name, 8.5, $script:lblPag.Font.Style)
        $script:lblPag.Text = "$($pg.Grupo)$parte ($($script:pagSkins + 1)/$($ps.Count))"
        return
    }
    if ($script:modoTienda -and $script:skin.Tienda) {
        # tienda de Sebastian: los objetos ocupan la cuadrícula de botones
        $i = 0
        foreach ($it in $script:skin.Tienda) {
            $b = Nuevo-Boton $it.Nombre (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
            $b.Font = Fnt($b.Font.FontFamily.Name, 7.5, [System.Drawing.FontStyle]::Bold)
            $b.Tag = @{ Tienda = $it }
            $b.Add_Click({ Tienda-Comprar $this.Tag.Tienda })
            Escalar $b; $grid.Controls.Add($b); $i++
        }
        $b = Nuevo-Boton 'Salir' (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
        $b.Add_Click({ Tienda-Salir }); Escalar $b; $grid.Controls.Add($b)
        $script:lblPag.Text = 'Tienda'
        return
    }
    if ($script:pagina -ge $script:totalPaginas) { $script:pagina = $script:totalPaginas - 1 }
    $inicio = $script:pagina * $PorPagina
    $fin = [Math]::Min($inicio + $PorPagina, @($script:Botones).Count) - 1
    $i = 0
    $deEstaPagina = if ($fin -ge $inicio) { @($script:Botones)[$inicio..$fin] } else { @() }
    foreach ($item in $deEstaPagina) {
        $b = Nuevo-Boton $item.Nombre (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
        $b.Tag = $item
        $b.Add_Click({ Lanzar $this.Tag })
        if ($hacker) { Hover-Color $b }
        Escalar $b; $grid.Controls.Add($b); $i++
    }
    $script:lblPag.Text = "Page $($script:pagina + 1)/$totalPaginas"
}

function Efecto-Entrada($prev) {
    $msg = Mensaje-Entrada $prev
    # sin intros: solo saluda
    if (-not $script:aj.Intros -or $script:aj.Epilepsia) { Decir $msg 'abiertos'; return }   # el modo seguro también quita las intros
    switch ($script:skin.Estilo) {
        'hacker' { Glitch 10 $msg }
        'web' { Transicion-Web $msg }
        'tele' { Transicion-Estatica $msg }
        'mew' { Transicion-Boss $msg }
        'lobo' { Transicion-Lobo $msg }
        'mlg' { Transicion-Scope $msg }
        'oeste' { Transicion-Wanted $msg }
        'gunsaw' { Transicion-Gunsaw $msg }
        'culto' { Transicion-Culto $msg }
        'kaiju' { Transicion-Kaiju $msg }
        'zorro' { Transicion-Zorro $msg }
        'pressure' { Transicion-Vent $msg }
        'dod' { Transicion-DoD $msg }
        'teto' { Transicion-Teto $msg }
        'enfosi' { Transicion-Enfosi $msg }
        'femta' { Transicion-Token $msg }
        'pop' { Transicion-Pop $msg }
        'pizza' { Transicion-Pizza $msg }
        'punk' { Transicion-Punk $msg }
        'gran' { Transicion-Gran $msg }
        'abismo' { Transicion-Nanachi $msg }
        'evil' { Transicion-Evil $msg }
        'niebla' { Transicion-Fuzzy $msg }
    }
}

# ================= GUÍA DEL PANDA =================
# La primera vez que abres el panel, el panda rojo de JOSEPABLINI CORPORATION te da la bienvenida y te enseña lo básico.
# Se vuelve a ver desde Ajustes → Guía del panda. Al terminarla (o saltarla) se apunta en ajustes.txt (Guia = si).
# Cada paso es @('qué se ilumina', 'texto'). Lo que se puede iluminar: nada, botones, paginas, skins, personaje, ajustes, barra
$PasosGuia = @(
    , @('nada', '¡Hola! Bienvenido a c00lgui. Soy el panda rojo de JOSEPABLINI CORPORATION y te voy a enseñar lo básico del panel. Es muy rápido, ¡prometido!')
    , @('botones', 'Estos botones abren tus cosas con un clic: YouTube, Word, Excel, el Bloc de notas... Si no tienes una app de Office instalada, te abro su versión web.')
    , @('paginas', 'Con < y > cambias de página. En la página 2 están los enlaces a GitHub y a Wikipedia, y algunas cosas más.')
    , @('skins', 'En Skins cambias de personaje. Cada uno tiene su estilo, sus frases, su intro y su minijuego. Van por grupos (YouTube, Roblox...) y el panel recuerda el último que elegiste.')
    , @('personaje', 'Este es tu asistente. Hazle clic y te contesta (o pasa algo, según la skin). Con clic derecho llama a otro personaje y se ponen a discutir.')
    , @('ajustes', 'En Ajustes quitas el sonido o las intros, cambias el tamaño y la opacidad... y con "Editar botones" pones tus propios botones en el orden que quieras.')
    , @('barra', 'Para mover el panel, arrástralo desde el título de arriba. Con _ lo minimizas y con X lo cierras.')
    , @('nada', 'Las intros tienen un botón SALTAR abajo a la derecha. Si quieres volver a verme, estoy en Ajustes → Guía del panda. ¡Eso es todo! Fear the Spaggety Code, Build the Larp.')
)
$script:guia = $null
$GuiaNaranja = (C 232 110 40)
function Buscar-Control($padre, $texto) {
    foreach ($c in $padre.Controls) {
        if (-not $c.Visible) { continue }
        if ($c.Text -eq $texto) { return $c }
        $h = Buscar-Control $c $texto; if ($h) { return $h }
    }
    return $null
}
function Rect-Control($c) {
    $p = $form.PointToClient($c.PointToScreen([System.Drawing.Point]::Empty))
    return (New-Object System.Drawing.Rectangle($p.X, $p.Y, $c.Width, $c.Height))
}
# lo que hay que iluminar, en píxeles de la ventana
function Rect-Guia($que) {
    $Z = $script:K; $cw = $form.ClientSize.Width; $ch = $form.ClientSize.Height
    switch ($que) {
        'botones' { if ($script:grid) { return (Rect-Control $script:grid) } }
        'paginas' { $a = Buscar-Control $form '<'; $b = Buscar-Control $form '>'; if ($a -and $b) { return [System.Drawing.Rectangle]::Union((Rect-Control $a), (Rect-Control $b)) } }
        'skins' { $c = Buscar-Control $form 'Skins'; if ($c) { return (Rect-Control $c) } }
        'ajustes' { $c = Buscar-Control $form 'Ajustes'; if ($c) { return (Rect-Control $c) } }
        'personaje' { return (New-Object System.Drawing.Rectangle([int](404 * $Z), [int](56 * $Z), [int]($cw - 410 * $Z), [int]($ch - 62 * $Z))) }
        'barra' { return (New-Object System.Drawing.Rectangle(0, 0, $cw, [int](52 * $Z))) }
    }
    return [System.Drawing.Rectangle]::Empty
}
function Guia-Boton($texto, $accion, $fondo) {
    $b = New-Object System.Windows.Forms.Button; $b.Text = $texto; $b.FlatStyle = 'Flat'; $b.Tag = $accion; $b.Cursor = 'Hand'
    $b.Font = Fnt('Segoe UI', 8.5, [System.Drawing.FontStyle]::Bold); $b.ForeColor = [System.Drawing.Color]::White; $b.BackColor = $fondo
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::White; $b.FlatAppearance.BorderSize = [Math]::Max(1, [int](1.5 * $script:K))
    $b.FlatAppearance.MouseOverBackColor = (C 255 150 70)
    $b.Size = New-Object System.Drawing.Size([int](112 * $script:K), [int](26 * $script:K))
    $b.Add_Click({ & $this.Tag })
    $script:guia.Ov.Controls.Add($b); return $b
}
function Abrir-Guia {
    if ($script:guia -or (Ocupado) -or $form.WindowState -eq 'Minimized') { return }
    Fin-Discusion $true
    if ($script:modoSkins) { $script:modoSkins = $false; Mostrar-Pagina }
    if ($script:vAj -and -not $script:vAj.IsDisposed) { $script:vAj.Close() }
    $form.Refresh()
    # foto del panel: se ve detrás, oscurecida, con la parte que explica iluminada
    $foto = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
    $form.DrawToBitmap($foto, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
    $script:transicion = $true
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0); $ov.Size = $form.ClientSize; $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $script:guia = @{ Paso = 0; Pos = 0; Foto = $foto; Panda = (Cargar-Img 'skins\guia\panda.png'); Fase = 0.0; Rect = [System.Drawing.Rectangle]::Empty; Izq = $false; Ov = $ov }
    $ov.Add_Paint({ Pintar-Guia $_.Graphics })
    $ov.Add_MouseDown({ Guia-Avanzar })
    $script:guia.Sig = Guia-Boton 'Siguiente  ▶' { Guia-Avanzar } $GuiaNaranja
    $script:guia.Atras = Guia-Boton '◀  Atrás' { if ($script:guia.Paso -gt 0) { Guia-Paso ($script:guia.Paso - 1) } } (C 60 50 48)
    $script:guia.Saltar = Guia-Boton 'Saltar guía' { Cerrar-Guia } (C 40 36 36)
    $form.Controls.Add($ov); $ov.BringToFront()
    Guia-Paso 0
    $guiaTimer.Start()
}
# coloca al panda, el bocadillo y los botones en el lado contrario a lo que se ilumina
function Guia-Paso($n) {
    $e = $script:guia; $e.Paso = $n; $e.Pos = 0
    $e.Rect = Rect-Guia $PasosGuia[$n][0]
    $cw = $form.ClientSize.Width
    $e.Izq = (-not $e.Rect.IsEmpty) -and (($e.Rect.X + $e.Rect.Width / 2) -gt ($cw / 2))
    $Z = $script:K; $W = $cw / $Z; $H = $form.ClientSize.Height / $Z
    $x0 = if ($e.Izq) { 8 } else { $W - 352 }
    # los botones, uno debajo de otro, en el lado de dentro (al lado del panda)
    $bx = if ($e.Izq) { $x0 + 344 - 112 } else { $x0 }
    $i = 0
    foreach ($b in @($e.Sig, $e.Atras, $e.Saltar)) { $b.Location = New-Object System.Drawing.Point([int]($bx * $Z), [int](($H - 104 + $i * 32) * $Z)); $i++ }
    $ultimo = ($n -ge $PasosGuia.Count - 1)
    $e.Sig.Text = if ($ultimo) { '¡Entendido!' } else { 'Siguiente  ▶' }
    $e.Atras.Visible = ($n -gt 0); $e.Saltar.Visible = -not $ultimo
    $e.Ov.Invalidate()
}
function Guia-Avanzar {
    $e = $script:guia; if (-not $e) { return }
    $txt = $PasosGuia[$e.Paso][1]
    if ($e.Pos -lt $txt.Length) { $e.Pos = $txt.Length; $e.Ov.Invalidate(); return }   # primero termina de escribir
    if ($e.Paso -ge $PasosGuia.Count - 1) { Cerrar-Guia } else { Guia-Paso ($e.Paso + 1) }
}
function Cerrar-Guia {
    $e = $script:guia; if (-not $e) { return }
    $guiaTimer.Stop()
    $form.Controls.Remove($e.Ov); $e.Ov.Dispose()
    if ($e.Foto) { $e.Foto.Dispose() }; if ($e.Panda) { $e.Panda.Dispose() }
    $script:guia = $null; $script:transicion = $false
    $script:aj.Guia = $true; Guardar-Ajustes
    $form.Invalidate()
    Decir (Azar $script:skin.Hola) 'abiertos'
}
function Pintar-Guia($g) {
    $e = $script:guia; if (-not $e) { return }
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'; $g.TextRenderingHint = 'AntiAlias'
    $cw = $e.Ov.Width; $ch = $e.Ov.Height
    $g.DrawImage($e.Foto, 0, 0, $e.Foto.Width, $e.Foto.Height)
    # todo oscuro menos lo que se explica, que se marca con un borde naranja que late
    $reg = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)))
    if (-not $e.Rect.IsEmpty) { $hueco = [System.Drawing.Rectangle]::Inflate($e.Rect, [int](4 * $script:K), [int](4 * $script:K)); $reg.Exclude($hueco) }
    $g.FillRegion((New-Object System.Drawing.SolidBrush((ARGB 175 0 0 0))), $reg); $reg.Dispose()
    if (-not $e.Rect.IsEmpty) {
        $al = [int](170 + 85 * [Math]::Sin($e.Fase * 1.6))
        $pen = New-Object System.Drawing.Pen((ARGB $al 255 150 60), [float](3 * $script:K))
        $g.DrawRectangle($pen, ($e.Rect.X - [int](4 * $script:K)), ($e.Rect.Y - [int](4 * $script:K)), ($e.Rect.Width + [int](8 * $script:K)), ($e.Rect.Height + [int](8 * $script:K))); $pen.Dispose()
    }
    # a partir de aquí, en las medidas del panel
    $g.ScaleTransform($script:K, $script:K)
    $W = $cw / $script:K; $H = $ch / $script:K
    $x0 = if ($e.Izq) { 8 } else { $W - 352 }
    # el panda asomando por abajo, moviéndose un poco
    $ph = 170; $pw = 220; $px = 0; $py = $H - 160 + [Math]::Sin($e.Fase) * 3
    if ($e.Panda) {
        $pw = $e.Panda.Width * $ph / $e.Panda.Height
        $px = if ($e.Izq) { $x0 } else { $x0 + 344 - $pw }
        if ($e.Izq) { $g.DrawImage($e.Panda, [float]($px + $pw), [float]$py, [float](-$pw), [float]$ph) } else { $g.DrawImage($e.Panda, [float]$px, [float]$py, [float]$pw, [float]$ph) }
    }
    # bocadillo con el texto que se va escribiendo
    $txt = $PasosGuia[$e.Paso][1]; $vis = $txt.Substring(0, [Math]::Min($txt.Length, $e.Pos))
    $f = FntP('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $alto = [Math]::Max(40, $g.MeasureString($txt, $f, 324).Height) + 30
    $by = 60; $bw = 344
    $tx = $px + $pw * 0.5; $bb = $by + $alto
    $r = Ruta-Redonda $x0 $by $bw $alto 12
    $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 90 0 0 0))), (Ruta-Redonda ($x0 + 3) ($by + 4) $bw $alto 12))
    $g.FillPath([System.Drawing.Brushes]::White, $r)
    $pico = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($tx - 12), [float]($bb - 2))), (New-Object System.Drawing.PointF([float]($tx + 12), [float]($bb - 2))), (New-Object System.Drawing.PointF([float]$tx, [float]($bb + 14))))
    $g.FillPolygon([System.Drawing.Brushes]::White, $pico)
    $borde = New-Object System.Drawing.Pen($GuiaNaranja, 2.5); $borde.LineJoin = 'Round'
    $g.DrawPath($borde, $r); $g.DrawLines($borde, $pico); $r.Dispose(); $borde.Dispose()
    $g.FillRectangle([System.Drawing.Brushes]::White, [float]($tx - 11), [float]($bb - 4), 22, 4)
    $g.DrawString("PANDA ROJO  ·  $($e.Paso + 1)/$($PasosGuia.Count)", (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($GuiaNaranja)), [float]($x0 + 10), [float]($by + 6))
    $g.DrawString($vis, $f, (New-Object System.Drawing.SolidBrush((C 30 26 26))), (New-Object System.Drawing.RectangleF([float]($x0 + 10), [float]($by + 22), 324, [float]($alto - 24))))
}
$guiaTimer = New-Object System.Windows.Forms.Timer
$guiaTimer.Interval = 30
$guiaTimer.Add_Tick({
    $e = $script:guia; if (-not $e) { $guiaTimer.Stop(); return }
    $e.Fase += 0.12
    $txt = $PasosGuia[$e.Paso][1]; if ($e.Pos -lt $txt.Length) { $e.Pos = [Math]::Min($txt.Length, $e.Pos + 2) }
    $e.Ov.Invalidate()
})
# la primera vez: espera a que acaben el logo y la intro, y sale la guía
$script:guiaCalma = 0
$guiaInicio = New-Object System.Windows.Forms.Timer
$guiaInicio.Interval = 250
$guiaInicio.Add_Tick({
    if ($script:aj.Guia) { $guiaInicio.Stop(); return }
    if ((Ocupado) -or $script:discutiendo -or $form.WindowState -eq 'Minimized') { $script:guiaCalma = 0; return }
    $script:guiaCalma++
    if ($script:guiaCalma -ge 6) { $guiaInicio.Stop(); Abrir-Guia }
})

# ================= VENTANA DE AJUSTES =================
function Opacidad-Base {
    $o = if ($script:skin) { [double]$script:skin.Opacidad } else { 1.0 }
    return [Math]::Max(0.3, $o * $script:aj.Opacidad / 100.0)
}
function Iniciar-Con-Windows($si) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'c00lgui.lnk'
    try {
        if ($si) {
            if (-not (Test-Path $lnk)) {
                $sh = New-Object -ComObject WScript.Shell; $a = $sh.CreateShortcut($lnk)
                $a.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'; $a.Arguments = '"' + (Join-Path $Raiz 'c00lgui.vbs') + '"'
                $a.WorkingDirectory = $Raiz; $a.Save()
            }
        } elseif (Test-Path $lnk) { Remove-Item $lnk -Force }
    } catch {}
}
function Aplicar-Ajustes {
    $form.TopMost = $script:aj.Encima
    if ($script:vAj -and -not $script:vAj.IsDisposed) { $script:vAj.TopMost = $script:aj.Encima }
    $form.Opacity = (Opacidad-Base)
    switch ($script:aj.Charla) {
        'mucha' { $idleTimer.Interval = 9000; $idleTimer.Start() }
        'poca' { $idleTimer.Interval = 45000; $idleTimer.Start() }
        'nunca' { $idleTimer.Stop() }
        default { $idleTimer.Interval = 18000; $idleTimer.Start() }
    }
    Iniciar-Con-Windows $script:aj.Inicio
}
$script:vAj = $null
function Mostrar-Ajustes {
    if ($script:vAj -and -not $script:vAj.IsDisposed) { $script:vAj.Activate(); return }
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'Ajustes'; $f.FormBorderStyle = 'FixedToolWindow'; $f.StartPosition = 'Manual'; $f.ShowInTaskbar = $false
    $f.BackColor = (C 30 30 38); $f.ForeColor = (C 236 236 242); $f.Font = Fnt('Segoe UI', 9)
    $f.Owner = $form; $f.TopMost = $script:aj.Encima
    $script:ajF = $f; $script:ajY = 12
    $titulo = New-Object System.Windows.Forms.Label; $titulo.Text = 'AJUSTES DEL PANEL'; $titulo.Font = Fnt('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $titulo.ForeColor = (C 255 200 90); $titulo.Location = New-Object System.Drawing.Point(14, $script:ajY); $titulo.AutoSize = $true; $f.Controls.Add($titulo); $script:ajY += 34
    [void](Aj-Casilla 'Sonido activado' 'Sonido')
    [void](Aj-Barra 'Volumen' 'Volumen' 0 100)
    [void](Aj-Casilla 'Discusiones con invitados' 'Invitados')
    [void](Aj-Casilla 'Intros al cambiar de skin' 'Intros')
    [void](Aj-Casilla 'Modo seguro (epilepsia): sin destellos ni temblores' 'Epilepsia')
    $charla = Aj-Lista 'Frases solas' 'Charla' @('Muchas', 'Normal', 'Pocas', 'Nunca') @('mucha', 'normal', 'poca', 'nunca')
    $charla.Add_SelectedIndexChanged({ $script:aj[$this.Tag.Clave] = $this.Tag.Valores[$this.SelectedIndex]; Guardar-Ajustes; Aplicar-Ajustes })
    $tam = Aj-Lista 'Tamaño' 'Tamano' @('Pequeño', 'Normal', 'Grande', 'Enorme') @([double]1.0, [double]1.2, [double]1.5, [double]1.8)
    $tam.Add_SelectedIndexChanged({
        $nuevo = [double]$this.Tag.Valores[$this.SelectedIndex]
        if ($nuevo -eq $script:aj.Tamano -or (Ocupado)) { return }
        $script:aj.Tamano = $nuevo; Guardar-Ajustes
        $script:K = [float]($script:dpiBase * $nuevo)
        Construir-UI; Aplicar-Ajustes; Decir 'Tamaño cambiado.' 'abiertos'
    })
    [void](Aj-Barra 'Opacidad' 'Opacidad' 40 100)
    [void](Aj-Casilla 'Siempre encima de las demás ventanas' 'Encima')
    [void](Aj-Casilla 'Recordar dónde dejé la ventana' 'Posicion')
    [void](Aj-Casilla 'Abrir al encender el ordenador' 'Inicio')
    # personalizar los botones del panel (orden y botones propios) y su tutorial
    $bEd = Ventana-Boton 'Editar botones...' 16 ($script:ajY + 6) 170 { Mostrar-Editor-Botones } (C 255 200 90)
    $bTu = Ventana-Boton 'Tutorial' 196 ($script:ajY + 6) 118 { Mostrar-Tutorial } (C 90 90 110)
    $bEd.ForeColor = (C 20 20 24); $f.Controls.AddRange(@($bEd, $bTu)); $script:ajY += 42
    # la guía del panda rojo (la que sale la primera vez)
    $bGu = Ventana-Boton 'Guía del panda' 16 ($script:ajY + 2) 298 { $script:vAj.Close(); Abrir-Guia } $GuiaNaranja
    $bGu.ForeColor = [System.Drawing.Color]::White; $f.Controls.Add($bGu); $script:ajY += 38
    $cerrar = New-Object System.Windows.Forms.Button; $cerrar.Text = 'Cerrar'; $cerrar.FlatStyle = 'Flat'; $cerrar.BackColor = (C 60 60 74)
    $cerrar.Location = New-Object System.Drawing.Point(120, ($script:ajY + 6)); $cerrar.Size = New-Object System.Drawing.Size(90, 30)
    $cerrar.Add_Click({ $script:vAj.Close() }); $f.Controls.Add($cerrar)
    $f.ClientSize = New-Object System.Drawing.Size(330, ($script:ajY + 48))
    Escalar $f
    # al lado del panel, donde quepa
    $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $x = if ($form.Right + $f.Width + 8 -le $wa.Right) { $form.Right + 8 } else { [Math]::Max($wa.Left, $form.Left - $f.Width - 8) }
    $f.Location = New-Object System.Drawing.Point($x, [Math]::Max($wa.Top, [Math]::Min($form.Top, $wa.Bottom - $f.Height)))
    $script:vAj = $f
    $f.Show()
}
function Aj-Casilla($texto, $clave) {
    $c = New-Object System.Windows.Forms.CheckBox; $c.Text = $texto; $c.Checked = [bool]$script:aj[$clave]; $c.Tag = $clave
    $c.Location = New-Object System.Drawing.Point(16, $script:ajY); $c.Size = New-Object System.Drawing.Size(300, 24); $c.FlatStyle = 'Flat'
    $c.Add_CheckedChanged({ $script:aj[$this.Tag] = $this.Checked; Guardar-Ajustes; Aplicar-Ajustes })
    $script:ajF.Controls.Add($c); $script:ajY += 28; return $c
}
function Aj-Etiqueta($texto) {
    $l = New-Object System.Windows.Forms.Label; $l.Text = $texto; $l.Location = New-Object System.Drawing.Point(16, ($script:ajY + 3)); $l.Size = New-Object System.Drawing.Size(120, 22)
    $script:ajF.Controls.Add($l)
}
function Aj-Lista($texto, $clave, $opciones, $valores) {
    Aj-Etiqueta $texto
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.DropDownStyle = 'DropDownList'; $cb.FlatStyle = 'Flat'
    $cb.Location = New-Object System.Drawing.Point(140, $script:ajY); $cb.Size = New-Object System.Drawing.Size(170, 24)
    foreach ($o in $opciones) { [void]$cb.Items.Add($o) }
    $idx = [Array]::IndexOf($valores, $script:aj[$clave]); if ($idx -lt 0) { $idx = 1 }; $cb.SelectedIndex = $idx
    $cb.Tag = @{ Clave = $clave; Valores = $valores }
    $script:ajF.Controls.Add($cb); $script:ajY += 32; return $cb
}
function Aj-Barra($texto, $clave, $min, $max) {
    Aj-Etiqueta $texto
    $tb = New-Object System.Windows.Forms.TrackBar; $tb.Minimum = $min; $tb.Maximum = $max; $tb.TickFrequency = 10; $tb.Value = [Math]::Max($min, [Math]::Min($max, [int]$script:aj[$clave]))
    $tb.Location = New-Object System.Drawing.Point(134, ($script:ajY - 2)); $tb.Size = New-Object System.Drawing.Size(182, 30); $tb.Tag = $clave
    $tb.Add_ValueChanged({ $script:aj[$this.Tag] = $this.Value; Guardar-Ajustes; Aplicar-Ajustes })
    $script:ajF.Controls.Add($tb); $script:ajY += 36; return $tb
}

# ================= EDITOR DE BOTONES (Ajustes > Editar botones) =================
# Cambia el orden de los botones del panel, añade los tuyos, edítalos o quítalos.
# Se trabaja sobre una copia ($script:edLista) y solo se guarda en botones.txt al pulsar Guardar.
$script:vEd = $null; $script:vTut = $null
function Ventana-Boton($texto, $x, $y, $w, $accion, $fondo) {
    $b = New-Object System.Windows.Forms.Button; $b.Text = $texto; $b.FlatStyle = 'Flat'; $b.Tag = $accion
    $b.BackColor = $(if ($fondo) { $fondo } else { (C 60 60 74) }); $b.FlatAppearance.BorderColor = (C 90 90 110)
    $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($w, 30)
    $b.Add_Click({ & $this.Tag })
    return $b
}
function Ventana-Texto($texto, $x, $y, $w, $gris, $alto = 20) {
    $l = New-Object System.Windows.Forms.Label; $l.Text = $texto; $l.AutoSize = $false
    $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, $alto)
    if ($gris) { $l.ForeColor = (C 160 160 176) }
    return $l
}
function Nueva-Ventana($titulo, $w, $h) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $titulo; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.ShowInTaskbar = $false
    $f.BackColor = (C 30 30 38); $f.ForeColor = (C 236 236 242); $f.Font = Fnt('Segoe UI', 9); $f.TopMost = $script:aj.Encima
    $f.ClientSize = New-Object System.Drawing.Size($w, $h)
    return $f
}
# "roblox.com" -> "https://roblox.com"; los programas, rutas y enlaces especiales se dejan como están
function Normalizar-Destino($s) {
    $s = ([string]$s).Trim().Trim('"')
    if (-not $s) { return '' }
    if ($s -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -or $s -match '^(\\|%|\.)') { return $s }
    if ($s -notmatch '\s' -and $s -match '^[\w-]+(\.[\w-]+)+(/.*)?$' -and $s -notmatch '\.(exe|bat|cmd|lnk|msc|txt|docx?|xlsx?|pptx?|pdf|png|jpe?g|gif|mp3|mp4|zip)$') { return "https://$s" }
    return $s
}
function Refrescar-Lista($sel) {
    $lb = $script:edLb; $lb.BeginUpdate(); $lb.Items.Clear()
    for ($i = 0; $i -lt $script:edLista.Count; $i++) { $b = $script:edLista[$i]; [void]$lb.Items.Add(('{0,2}.  {1}      ({2})' -f ($i + 1), $b.Nombre, $b.Abrir)) }
    $lb.EndUpdate()
    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = [Math]::Max(0, [Math]::Min($sel, $lb.Items.Count - 1)) }
    $pags = [Math]::Max(1, [Math]::Ceiling($script:edLista.Count / $PorPagina))
    $script:edInfo.Text = "$($script:edLista.Count) botones  ·  $pags página(s) de $PorPagina"
}
function Mostrar-Editor-Botones {
    if ($script:vEd -and -not $script:vEd.IsDisposed) { $script:vEd.Activate(); return }
    $script:edLista = New-Object System.Collections.ArrayList
    foreach ($b in (Copiar-Botones $script:Botones)) { [void]$script:edLista.Add($b) }
    $f = Nueva-Ventana 'Editar botones' 470 420; $f.StartPosition = 'CenterScreen'
    $t = Ventana-Texto 'TUS BOTONES  (el de arriba es el primero del panel)' 14 10 440; $t.Font = Fnt('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold); $t.ForeColor = (C 255 200 90)
    $lb = New-Object System.Windows.Forms.ListBox; $lb.Location = New-Object System.Drawing.Point(14, 34); $lb.Size = New-Object System.Drawing.Size(300, 330)
    $lb.BackColor = (C 20 20 26); $lb.ForeColor = (C 236 236 242); $lb.BorderStyle = 'FixedSingle'; $lb.IntegralHeight = $false; $lb.HorizontalScrollbar = $true
    $lb.Add_DoubleClick({ Ed-Editar })
    $script:edLb = $lb
    $script:edInfo = Ventana-Texto '' 14 370 300 $true
    $x = 326; $w = 130
    $f.Controls.AddRange(@($t, $lb, $script:edInfo,
        (Ventana-Boton '▲  Subir' $x 34 $w { Ed-Mover -1 }),
        (Ventana-Boton '▼  Bajar' $x 70 $w { Ed-Mover 1 }),
        (Ventana-Boton '+  Añadir' $x 116 $w { Ed-Anadir } (C 40 110 60)),
        (Ventana-Boton 'Editar' $x 152 $w { Ed-Editar }),
        (Ventana-Boton 'Quitar' $x 188 $w { Ed-Quitar } (C 120 40 46)),
        (Ventana-Boton 'De serie' $x 234 $w { Ed-DeSerie }),
        (Ventana-Boton '?  Tutorial' $x 270 $w { Mostrar-Tutorial }),
        (Ventana-Boton 'Guardar' $x 326 $w { Ed-Guardar } (C 255 200 90)),
        (Ventana-Boton 'Cancelar' $x 362 $w { $script:vEd.Close() })))
    ($f.Controls | Where-Object { $_.Text -eq 'Guardar' }).ForeColor = (C 20 20 24)
    Escalar $f
    $script:vEd = $f
    Refrescar-Lista 0
    $f.Show()
}
function Ed-Mover($d) {
    $i = $script:edLb.SelectedIndex; $j = $i + $d
    if ($i -lt 0 -or $j -lt 0 -or $j -ge $script:edLista.Count) { return }
    $tmp = $script:edLista[$i]; $script:edLista[$i] = $script:edLista[$j]; $script:edLista[$j] = $tmp
    Refrescar-Lista $j
}
function Ed-Anadir {
    $n = Pedir-Boton $null
    if (-not $n) { return }
    # el botón nuevo va justo debajo del que está elegido (o al final)
    $i = $script:edLb.SelectedIndex
    if ($i -ge 0) { $script:edLista.Insert($i + 1, $n); Refrescar-Lista ($i + 1) } else { [void]$script:edLista.Add($n); Refrescar-Lista ($script:edLista.Count - 1) }
}
function Ed-Editar {
    $i = $script:edLb.SelectedIndex; if ($i -lt 0) { return }
    $n = Pedir-Boton $script:edLista[$i]
    if ($n) { $script:edLista[$i] = $n; Refrescar-Lista $i }
}
function Ed-Quitar {
    $i = $script:edLb.SelectedIndex; if ($i -lt 0) { return }
    $r = [System.Windows.Forms.MessageBox]::Show($script:vEd, "¿Quitar el botón '$($script:edLista[$i].Nombre)'?", 'Quitar botón', 'YesNo', 'Question')
    if ($r -eq 'Yes') { $script:edLista.RemoveAt($i); Refrescar-Lista $i }
}
function Ed-DeSerie {
    $r = [System.Windows.Forms.MessageBox]::Show($script:vEd, '¿Volver a los botones de serie? Se quitarán los tuyos y el orden que hayas puesto.', 'Botones de serie', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    $script:edLista.Clear(); foreach ($b in (Copiar-Botones $BotonesDeSerie)) { [void]$script:edLista.Add($b) }
    Refrescar-Lista 0
}
function Ed-Guardar {
    if ($script:edLista.Count -eq 0) { [void][System.Windows.Forms.MessageBox]::Show($script:vEd, 'Tiene que quedar al menos un botón.', 'Guardar', 'OK', 'Information'); return }
    if (-not (Guardar-Botones $script:edLista)) { [void][System.Windows.Forms.MessageBox]::Show($script:vEd, 'No se ha podido guardar botones.txt.', 'Guardar', 'OK', 'Warning'); return }
    $script:Botones = Copiar-Botones $script:edLista
    Contar-Paginas; $script:pagina = 0
    if (-not $script:modoSkins -and -not $script:modoTienda) { Mostrar-Pagina }
    $script:vEd.Close()
    Decir '¡Botones guardados! Ya están en el panel, en tu orden.' 'abiertos'
}
# ventanita para crear o editar un botón; devuelve el botón o $null si se cancela
function Pedir-Boton($b) {
    $d = Nueva-Ventana $(if ($b) { 'Editar botón' } else { 'Botón nuevo' }) 400 316; $d.StartPosition = 'CenterParent'
    $script:pbN = New-Object System.Windows.Forms.TextBox; $script:pbA = New-Object System.Windows.Forms.TextBox; $script:pbW = New-Object System.Windows.Forms.TextBox
    foreach ($tb in @($script:pbN, $script:pbA, $script:pbW)) { $tb.BackColor = (C 20 20 26); $tb.ForeColor = (C 236 236 242); $tb.BorderStyle = 'FixedSingle'; $tb.Size = New-Object System.Drawing.Size(370, 24) }
    $script:pbN.Location = New-Object System.Drawing.Point(14, 34); $script:pbN.MaxLength = 30
    $script:pbA.Location = New-Object System.Drawing.Point(14, 92)
    $script:pbW.Location = New-Object System.Drawing.Point(14, 190)
    if ($b) { $script:pbN.Text = $b.Nombre; $script:pbA.Text = $b.Abrir; $script:pbW.Text = $b.Web }
    $ok = Ventana-Boton 'Aceptar' 174 272 100 { Pb-Aceptar $this.FindForm() } (C 255 200 90); $ok.ForeColor = (C 20 20 24)
    $no = Ventana-Boton 'Cancelar' 284 272 100 { $this.FindForm().DialogResult = 'Cancel' }
    $d.Controls.AddRange(@(
        (Ventana-Texto 'Nombre (lo que pone en el botón, mejor corto)' 14 12 370), $script:pbN,
        (Ventana-Texto 'Qué abre: una web, un programa, un archivo o una carpeta' 14 70 370), $script:pbA,
        (Ventana-Boton 'Archivo...' 14 122 110 { Pb-Archivo }),
        (Ventana-Boton 'Carpeta...' 132 122 110 { Pb-Carpeta }),
        (Ventana-Boton 'Probar' 274 122 110 { Pb-Probar } (C 40 110 60)),
        (Ventana-Texto 'Web por si el programa no está instalado (opcional)' 14 168 370), $script:pbW,
        (Ventana-Texto "Ejemplos:  roblox.com  ·  notepad.exe`n%USERPROFILE%\Downloads  ·  steam://rungameid/730" 14 222 370 $true 40),
        $ok, $no))
    $d.AcceptButton = $ok; $d.CancelButton = $no
    Escalar $d
    $dueno = if ($script:vEd -and -not $script:vEd.IsDisposed) { $script:vEd } else { $form }
    if ($d.ShowDialog($dueno) -ne 'OK') { $d.Dispose(); return $null }
    $res = @{ Nombre = $script:pbN.Text.Trim().Replace('|', '/'); Abrir = (Normalizar-Destino $script:pbA.Text).Replace('|', '/'); Web = (Normalizar-Destino $script:pbW.Text).Replace('|', '/') }
    $d.Dispose(); return $res
}
function Pb-Aceptar($d) {
    if (-not $script:pbN.Text.Trim()) { [void][System.Windows.Forms.MessageBox]::Show($d, 'Ponle un nombre al botón.', 'Falta el nombre', 'OK', 'Information'); $script:pbN.Focus(); return }
    if (-not $script:pbA.Text.Trim()) { [void][System.Windows.Forms.MessageBox]::Show($d, 'Escribe qué tiene que abrir (o usa Archivo... / Carpeta...).', 'Falta qué abre', 'OK', 'Information'); $script:pbA.Focus(); return }
    $d.DialogResult = 'OK'
}
function Pb-Archivo {
    $o = New-Object System.Windows.Forms.OpenFileDialog; $o.Title = 'Elige el programa o el archivo'
    $o.Filter = 'Programas y accesos directos|*.exe;*.lnk;*.bat;*.url|Todos los archivos|*.*'
    if ($o.ShowDialog() -eq 'OK') {
        $script:pbA.Text = $o.FileName
        if (-not $script:pbN.Text.Trim()) { $script:pbN.Text = [IO.Path]::GetFileNameWithoutExtension($o.FileName) }
    }
}
function Pb-Carpeta {
    $o = New-Object System.Windows.Forms.FolderBrowserDialog; $o.Description = 'Elige la carpeta que abrirá el botón'
    if ($o.ShowDialog() -eq 'OK') {
        $script:pbA.Text = $o.SelectedPath
        if (-not $script:pbN.Text.Trim()) { $script:pbN.Text = Split-Path $o.SelectedPath -Leaf }
    }
}
function Pb-Probar {
    $dest = Normalizar-Destino $script:pbA.Text
    if (-not $dest) { return }
    try { Start-Process ([Environment]::ExpandEnvironmentVariables($dest)) -ErrorAction Stop }
    catch { [void][System.Windows.Forms.MessageBox]::Show("No se ha podido abrir:`n$dest`n`nRevisa que esté bien escrito.", 'Probar', 'OK', 'Warning') }
}

# ================= TUTORIAL (una hoja en blanco) =================
# Una hoja de cuaderno con los pasos para personalizar los botones. El texto se dibuja sobre la hoja,
# encima de sus rayas; si no cabe, la hoja se mueve con la rueda del ratón.
# Para cambiar el tutorial, edita la lista $TextoTutorial: cada línea es @('tipo', 'texto').
# Tipos: titulo, paso, normal, codigo, nota y hueco (línea en blanco). Cada línea empieza por una coma (para que PowerShell no junte las líneas).
$TextoTutorial = @(
    , @('titulo', 'Cómo poner tus propios botones')
    , @('normal', 'Puedes cambiar el orden de los botones del panel y añadir los tuyos: páginas web, programas, juegos, archivos o carpetas.')
    , @('hueco', '')
    , @('paso', '1. Abre el editor')
    , @('normal', 'Pulsa el botón Ajustes (arriba del panel) y luego "Editar botones...". Verás la lista de todos tus botones, en orden.')
    , @('hueco', '')
    , @('paso', '2. Cambia el orden')
    , @('normal', 'Haz clic en un botón de la lista y pulsa ▲ Subir o ▼ Bajar. El de arriba del todo es el primero del panel. En cada página caben 12 botones; los demás pasan a la siguiente (con < y >).')
    , @('hueco', '')
    , @('paso', '3. Añade un botón tuyo')
    , @('normal', 'Pulsa + Añadir y rellena:')
    , @('normal', '•  Nombre: lo que pondrá en el botón. Mejor corto (unas 12 letras).')
    , @('normal', '•  Qué abre: puede ser...')
    , @('codigo', 'una web:          roblox.com')
    , @('codigo', 'un programa:      notepad.exe   (o "Archivo...")')
    , @('codigo', 'una carpeta:      %USERPROFILE%\Downloads')
    , @('codigo', 'un juego Steam:   steam://rungameid/730')
    , @('normal', '•  Web por si no está instalado: opcional. Si el programa no está en el ordenador, se abre esta web.')
    , @('normal', 'Pulsa Probar para comprobar que abre lo que quieres, y luego Aceptar.')
    , @('nota', 'El botón nuevo aparece debajo del que tenías elegido en la lista.')
    , @('hueco', '')
    , @('paso', '4. Edita o quita botones')
    , @('normal', 'Elige uno y pulsa Editar (o haz doble clic) para cambiarlo, o Quitar para borrarlo.')
    , @('hueco', '')
    , @('paso', '5. Guarda')
    , @('normal', 'Pulsa Guardar y el panel se actualiza al momento. Si pulsas Cancelar, no cambia nada.')
    , @('hueco', '')
    , @('paso', '¿Te has liado?')
    , @('normal', 'Pulsa "De serie" en el editor y vuelven los botones de siempre (YouTube, Word, Excel...).')
    , @('hueco', '')
    , @('paso', 'Truco: con el Bloc de notas')
    , @('normal', 'Tus botones se guardan en botones.txt, en la carpeta del panel. Ábrelo con el Bloc de notas: una línea por botón, así:')
    , @('codigo', 'Nombre | qué abre | web si no está')
    , @('codigo', 'YouTube | https://www.youtube.com')
    , @('codigo', 'Discord | discord: | https://discord.com/app')
    , @('codigo', 'Descargas | %USERPROFILE%\Downloads')
    , @('nota', 'Si borras botones.txt, vuelven los botones de serie. Cierra y abre el panel para ver los cambios hechos a mano.')
)
function Tut-Fuente($tipo) {
    switch ($tipo) {
        'titulo' { return (Fnt('Segoe Print', 15, [System.Drawing.FontStyle]::Bold)) }
        'paso' { return (Fnt('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)) }
        'codigo' { return (Fnt('Consolas', 9.5)) }
        'nota' { return (Fnt('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)) }
        default { return (Fnt('Segoe UI', 10)) }
    }
}
function Tut-Color($tipo) {
    switch ($tipo) { 'titulo' { return (C 30 40 120) } 'paso' { return (C 200 30 60) } 'codigo' { return (C 20 90 150) } 'nota' { return (C 110 110 120) } default { return (C 30 30 36) } }
}
# coloca cada línea en la hoja (en píxeles) y devuelve el alto total
function Tut-Maquetar($papel) {
    $Z = $script:K; $g = $papel.CreateGraphics()
    $x = 56 * $Z; $ancho = $papel.Width - $x - 18 * $Z; $y = 16 * $Z
    $script:tutPos = New-Object System.Collections.ArrayList
    foreach ($l in $TextoTutorial) {
        $tipo = $l[0]; $txt = $l[1]
        if ($tipo -eq 'hueco') { $y += 10 * $Z; continue }
        $f = Tut-Fuente $tipo
        $xx = if ($tipo -eq 'codigo') { $x + 16 * $Z } else { $x }
        $h = $g.MeasureString($txt, $f, [int]($ancho - ($xx - $x))).Height
        [void]$script:tutPos.Add(@{ T = $txt; K = $tipo; F = $f; R = (New-Object System.Drawing.RectangleF([float]$xx, [float]$y, [float]($ancho - ($xx - $x)), [float]($h + 2))) })
        $y += $h + $(if ($tipo -in @('titulo', 'paso')) { 4 * $Z } else { 2 * $Z })
    }
    $g.Dispose()
    return [int]($y + 20 * $Z)
}
function Mostrar-Tutorial {
    if ($script:vTut -and -not $script:vTut.IsDisposed) { $script:vTut.Activate(); return }
    $f = Nueva-Ventana 'Tutorial: tus botones' 520 500; $f.StartPosition = 'CenterScreen'; $f.BackColor = (C 206 198 186)
    # marco con barra de desplazamiento y, dentro, la hoja de papel
    $marco = New-Object System.Windows.Forms.Panel; $marco.Location = New-Object System.Drawing.Point(16, 14); $marco.Size = New-Object System.Drawing.Size(488, 434)
    $marco.BackColor = [System.Drawing.Color]::White; $marco.AutoScroll = $true
    $papel = New-Object System.Windows.Forms.Panel; $papel.Location = New-Object System.Drawing.Point(0, 0); $papel.Size = New-Object System.Drawing.Size(468, 434); $papel.BackColor = [System.Drawing.Color]::White
    Doble-Buffer $papel
    $papel.Add_Paint({
        $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'; $Z = $script:K
        # rayas azules, margen rojo y agujeros de cuaderno
        $lin = New-Object System.Drawing.Pen((C 205 222 242), [float]$Z)
        for ($yy = 30 * $Z; $yy -lt $this.Height; $yy += 22 * $Z) { $g.DrawLine($lin, 0, [float]$yy, [float]$this.Width, [float]$yy) }
        $lin.Dispose()
        $g.DrawLine((New-Object System.Drawing.Pen((C 236 120 130), [float](1.5 * $Z))), [float](42 * $Z), 0, [float](42 * $Z), [float]$this.Height)
        for ($yy = 110 * $Z; $yy -lt $this.Height; $yy += 260 * $Z) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 206 198 186))), [float](14 * $Z), [float]$yy, [float](16 * $Z), [float](16 * $Z)) }
        foreach ($p in $script:tutPos) {
            if ($p.K -eq 'codigo') { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 160 238 244 252))), [float]($p.R.X - 6 * $Z), $p.R.Y, [float]($p.R.Width + 6 * $Z), $p.R.Height) }
            $g.DrawString($p.T, $p.F, (New-Object System.Drawing.SolidBrush((Tut-Color $p.K))), $p.R)
        }
    })
    $marco.Controls.Add($papel)
    # la rueda del ratón mueve la hoja aunque el ratón esté encima del papel
    $papel.Add_MouseEnter({ $this.Parent.Focus() })
    $cer = Ventana-Boton 'Cerrar' 404 460 100 { $script:vTut.Close() }
    $edi = Ventana-Boton 'Abrir el editor' 254 460 140 { Mostrar-Editor-Botones } (C 255 200 90); $edi.ForeColor = (C 20 20 24)
    $f.Controls.AddRange(@($marco, $cer, $edi))
    Escalar $f
    # la hoja ocupa todo el ancho (menos la barra) y tan alta como el texto
    $papel.Width = $marco.ClientSize.Width - [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
    $papel.Height = [Math]::Max($marco.ClientSize.Height, (Tut-Maquetar $papel))
    $script:vTut = $f
    $f.Show()
}

function Aplicar-Skin($nombre) {
    if (Ocupado) { return }
    $prev = $script:skinNombre
    Set-Content -Path $ArchivoSkin -Value $nombre -Encoding UTF8
    $script:modoSkins = $false
    if ($nombre -eq $prev) { Mostrar-Pagina; return }
    if ($Skins[$nombre].Estilo -eq 'hacker') {
        # el panel "se rompe" y renace como c00lgui
        Glitch 14 @{ Skin = $nombre; Prev = $prev }
    } else {
        $script:skinNombre = $nombre
        Construir-UI
        Efecto-Entrada $prev
    }
}

# ================= VENTANA =================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'c00lgui'
$form.FormBorderStyle = 'None'
$form.StartPosition = 'CenterScreen'
Doble-Buffer $form

$form.Add_Paint({
    $k = $script:skin; $g = $_.Graphics
    $g.ScaleTransform($script:K, $script:K)
    $W = [int]($form.ClientSize.Width / $script:K); $H = [int]($form.ClientSize.Height / $script:K)
    switch ($k.Estilo) {
        'web' {
            $g.SmoothingMode = 'AntiAlias'
            $rect = New-Object System.Drawing.Rectangle(0, 0, $W, 52)
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $k.Barra1, $k.Barra2, 90)
            $g.FillRectangle($br, $rect); $br.Dispose()
            # icono "i" amarillo, como el de la camiseta de SeaDrive
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 198 26))), 12, 11, 30, 30)
            $g.DrawEllipse((New-Object System.Drawing.Pen((C 20 20 20), 2)), 12, 11, 30, 30)
            $g.DrawString('i', (FntP('Georgia', 15, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, 20, 12)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 140 220 60))), 0, 52, $W, 4)
            # barra del navegador
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 244 246 249))), 0, 56, $W, 32)
            $g.DrawLine((New-Object System.Drawing.Pen((C 200 205 212), 1)), 0, 88, $W, 88)
            $g.DrawString('◀   ▶   ⟳', (FntP('Segoe UI Symbol', 10)), (New-Object System.Drawing.SolidBrush((C 90 100 115))), 10, 61)
            $g.FillRectangle([System.Drawing.Brushes]::White, 96, 60, ($W - 112), 24)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 185 195 205), 1)), 96, 60, ($W - 112), 24)
            $g.FillRectangle([System.Drawing.Brushes]::Black, 0, $H - 10, $W, 10)
            $g.FillRectangle([System.Drawing.Brushes]::White, 0, $H - 7, $W, 2)
        }
        'tele' {
            $g.SmoothingMode = 'AntiAlias'
            $lun = New-Object System.Drawing.SolidBrush((C 255 95 70))
            for ($y = 64; $y -lt $H; $y += 22) { for ($x = (($y / 22) % 2) * 11; $x -lt $W; $x += 22) { $g.FillEllipse($lun, $x, $y, 7, 7) } }
            $lun.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 58 44 190))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 225 50))), 0, 52, $W, 5)
            $g.DrawString($k.Titulo, (FntP($k.FuenteTitulo, 20, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, 15, 9)
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 4)
            $g.DrawLine($pen, 472, 66, 454, 48); $g.DrawLine($pen, 538, 66, 556, 48)
            $g.FillEllipse([System.Drawing.Brushes]::Black, 446, 41, 12, 12); $g.FillEllipse([System.Drawing.Brushes]::Black, 552, 41, 12, 12)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $rx = 402; $ry = 64; $rw = 206; $rh = 170; $rr = 26
            $path.AddArc($rx, $ry, $rr, $rr, 180, 90); $path.AddArc($rx + $rw - $rr, $ry, $rr, $rr, 270, 90)
            $path.AddArc($rx + $rw - $rr, $ry + $rh - $rr, $rr, $rr, 0, 90); $path.AddArc($rx, $ry + $rh - $rr, $rr, $rr, 90, 90); $path.CloseFigure()
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 58 44 190))), $path); $g.DrawPath($pen, $path); $path.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 225 50))), 420, 214, 12, 12); $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)), 420, 214, 12, 12)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 90 220 245))), 438, 214, 12, 12); $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)), 438, 214, 12, 12)
            $g.DrawString('CH 03', (FntP('Comic Sans MS', 8, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 548, 213)
            $pen.Dispose()
            $arco = @((C 255 40 40), (C 255 150 30), (C 255 225 50), (C 90 210 80), (C 90 220 245), (C 58 44 190), (C 230 80 200))
            $bw = [Math]::Ceiling($W / $arco.Count)
            for ($i = 0; $i -lt $arco.Count; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush($arco[$i])), ($i * $bw), ($H - 10), $bw, 10) }
        }
        'gunsaw' {
            # pantalla CRT morada del menú de personajes de Gunsaw
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($k.Fondo)), 0, 0, $W, $H)
            $lin = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(16, 255, 255, 255), 1)
            for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($lin, 0, $y, $W, $y) }
            $lin.Dispose()
            $g.SmoothingMode = 'AntiAlias'
            $gris = New-Object System.Drawing.Pen((C 125 112 130), 1)
            $g.DrawString('A-D to switch skins', (FntP('Consolas', 8, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 200 195 205))), 180, 6)
            $g.DrawLine($gris, 12, 56, ($W - 12), 56)
            $g.DrawRectangle($gris, 409, 61, 191, 151)
            $g.DrawString('Character', (FntP('Consolas', 9, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 205 200 210))), 408, 215)
            # caja de estadísticas
            $g.DrawRectangle($gris, 16, 276, 376, 24)
            if ($k.Hambre) {
                Texto-Marcado $g "Aim {g}135%{b}  Health {r}90{b}  HAMBRE" (FntP('Consolas', 8.5, [System.Drawing.FontStyle]::Bold)) 22 281
                $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 50 36 28))), 248, 282, 136, 12)
                $colH = if ($script:hambre -ge 100) { (C 230 40 40) } else { $k.Acento }
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($colH)), 248, 282, [int](136 * $script:hambre / 100), 12)
                $g.DrawRectangle($gris, 248, 282, 136, 12)
            } else {
                Texto-Marcado $g "Aim {r}90%{b}  Move {r}93%{b}  Health {g}120{b}  Telarañas: {r}$($script:telas)" (FntP('Consolas', 8.5, [System.Drawing.FontStyle]::Bold)) 22 281
            }
            $gris.Dispose()
            if ($k.Agua) {
                # agua con olas animadas bajo Dune
                $pts = New-Object System.Collections.ArrayList
                for ($x = 0; $x -le $W; $x += 8) { [void]$pts.Add((New-Object System.Drawing.PointF($x, [float](304 + [Math]::Sin($x / 26.0 + $script:fase) * 3)))) }
                [void]$pts.Add((New-Object System.Drawing.PointF($W, $H))); [void]$pts.Add((New-Object System.Drawing.PointF(0, $H)))
                $g.FillPolygon((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 60, 150, 170))), [System.Drawing.PointF[]]$pts.ToArray())
            }
            # marco redondeado del monitor
            $marco = Ruta-Redonda 2 2 ($W - 4) ($H - 4) 26
            $g.DrawPath((New-Object System.Drawing.Pen((C 10 4 12), 6)), $marco); $marco.Dispose()
        }
        'lobo' {
            if (-not $script:bmpHex) { $script:bmpHex = Fondo-Hexagonos 616 344 (C 30 38 48) }
            $g.DrawImage($script:bmpHex, 0, 0, 616, 344)
            $g.SmoothingMode = 'AntiAlias'
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 18 23 30))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 170 40))), 0, 52, $W, 2)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 60 170 160))), 0, 56, $W, 1)
            # esquinas del marco del retrato
            $am = New-Object System.Drawing.Pen((C 255 170 40), 3)
            $x1 = 406; $y1 = 62; $x2 = 604; $y2 = 218; $L = 16
            $g.DrawLine($am, $x1, $y1, $x1 + $L, $y1); $g.DrawLine($am, $x1, $y1, $x1, $y1 + $L)
            $g.DrawLine($am, $x2, $y1, $x2 - $L, $y1); $g.DrawLine($am, $x2, $y1, $x2, $y1 + $L)
            $g.DrawLine($am, $x1, $y2, $x1 + $L, $y2); $g.DrawLine($am, $x1, $y2, $x1, $y2 - $L)
            $g.DrawLine($am, $x2, $y2, $x2 - $L, $y2); $g.DrawLine($am, $x2, $y2, $x2, $y2 - $L)
            $am.Dispose()
            # cuota de energía
            $g.DrawString("CUOTA DE ENERGÍA   $($script:energia)%", (FntP('Bahnschrift', 8)), (New-Object System.Drawing.SolidBrush((C 255 176 50))), 14, 274)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 32 14))), 16, 290, 376, 8)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 170 40))), 16, 290, [int](376 * $script:energia / 100), 8)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 120 85 25), 1)), 16, 290, 376, 8)
        }
        'mlg' {
            $g.SmoothingMode = 'AntiAlias'
            # degradado azul -> rojo de PURSUITCORE con rayas diagonales
            $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (C 57 72 191), (C 229 45 45), 35)
            $g.FillRectangle($br, 0, 0, $W, $H); $br.Dispose()
            $ray = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(22, 255, 255, 255), 10)
            for ($x = -$H; $x -lt $W; $x += 34) { $g.DrawLine($ray, $x, $H, ($x + $H), 0) }
            $ray.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 14 14 28))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 255 0))), 0, 52, $W, 3)
            if ($script:imgs.titulo) { $g.DrawImage($script:imgs.titulo, 8, 4, 150, 47) }
            # marco lima del retrato
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 255 0), 3)), 408, 60, 193, 153)
            # barra de carga del Snipe
            $g.FillRectangle([System.Drawing.Brushes]::Black, 410, 216, 190, 10)
            if ($script:snApuntando) {
                $c = if ($script:snCarga -ge 60) { [System.Drawing.Color]::Red } elseif ($script:snCarga -ge 20) { [System.Drawing.Color]::Yellow } else { [System.Drawing.Color]::White }
                $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), 410, 216, [int](190 * [Math]::Min(1.0, $script:snCarga / 60.0)), 10)
            }
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 255 0), 1)), 410, 216, 190, 10)
            $g.DrawString("HITMARKERS: $($script:hitsTotal)    DO THE DEW: $($script:dew)", (FntP('Arial Black', 8)), (New-Object System.Drawing.SolidBrush((C 191 239 255))), 16, 280)
        }
        { $_ -in @('culto', 'kaiju', 'zorro', 'mew', 'oeste', 'pressure', 'dod', 'teto', 'femta', 'pop', 'pizza', 'punk', 'enfosi', 'gran', 'abismo', 'evil', 'niebla') } {
            # skins nuevas: fondo real + personajes grandes + efectos + bocadillo propio
            $g.SmoothingMode = 'AntiAlias'
            # el fondo se prepara siempre con el tamaño fijo de la skin (no con el de la ventana a medio montar)
            if (-not $script:bmpEscena) { $script:bmpEscena = Fondo-Escena $k $k.Ancho $k.Alto }
            $g.DrawImage($script:bmpEscena, 0, 0, $k.Ancho, $k.Alto)
            if ($k.Estilo -eq 'kaiju' -and $script:kFase.P -and -not $script:kFin) {
                $gl = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(400, 120, ($W - 400), 140)), [System.Drawing.Color]::FromArgb(0, 255, 120, 30), [System.Drawing.Color]::FromArgb(120, 255, 90, 20), 90)
                $g.FillRectangle($gl, 400, 121, ($W - 400), 138); $gl.Dispose()
            }
            Pintar-Actores $g
            switch ($k.Estilo) {
                'culto' {
                    # ritual: todo se tiñe de rojo y salen tentáculos del suelo
                    if ($script:ritualFx -gt 0) {
                        $a = [int]([Math]::Min(1.0, $script:ritualFx / 20.0) * 110)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, 160, 0, 20))), 0, 0, $W, $H)
                        $alto = [Math]::Sin([Math]::Min(1.0, (44 - $script:ritualFx) / 14.0) * [Math]::PI / 2) * 150
                        $ten = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 34, 10, 34), 11); $ten.StartCap = 'Round'; $ten.EndCap = 'Round'
                        $ten2 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 120, 40, 120), 4); $ten2.StartCap = 'Round'; $ten2.EndCap = 'Round'
                        foreach ($tx in @(30, 140, 260, 420, 520, 640, 730)) {
                            $o = [Math]::Sin($script:fase * 2 + $tx) * 22
                            foreach ($pn in @($ten, $ten2)) { $g.DrawBezier($pn, [float]$tx, [float]$H, [float]($tx + $o), [float]($H - $alto * 0.4), [float]($tx - $o), [float]($H - $alto * 0.7), [float]($tx + $o * 1.5), [float]($H - $alto)) }
                        }
                        $ten.Dispose(); $ten2.Dispose()
                    }
                    # fe del culto y seguidores
                    Texto-Contorno $g 'FE' 'Palatino Linotype' 15 14 274 (C 238 206 120) 3
                    $marco = Ruta-Redonda 46 279 210 15 10
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 40 14 18))), $marco)
                    if ($script:fe -gt 0) {
                        $col1 = if ($script:fe -lt 25) { (C 110 110 110) } else { (C 170 24 34) }; $col2 = if ($script:fe -lt 25) { (C 160 160 160) } else { (C 236 190 70) }
                        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(46, 279, 210, 15)), $col1, $col2, 0)
                        $g.FillRectangle($br, 48, 281, [int](206 * $script:fe / 100), 11); $br.Dispose()
                    }
                    $g.DrawPath((New-Object System.Drawing.Pen((C 214 170 60), 2)), $marco); $marco.Dispose()
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 176 128 214))), 272, 280, 13, 13)
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 176 128 214))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(272, 284)), (New-Object System.Drawing.PointF(271, 276)), (New-Object System.Drawing.PointF(277, 281))))
                    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 176 128 214))), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF(285, 284)), (New-Object System.Drawing.PointF(286, 276)), (New-Object System.Drawing.PointF(280, 281))))
                    Texto-Contorno $g "$($script:seguidores) seguidores" 'Palatino Linotype' 14 290 275 (C 226 200 250) 3
                }
                'kaiju' {
                    Pintar-Particulas $g
                    Vida-Kaiju $g 'PYROPHINA' $script:kHP.P 420 62 156 (C 240 90 30) $script:kFase.P
                    Vida-Kaiju $g 'ZARATANA' $script:kHP.Z 590 62 156 (C 150 140 210) $script:kFase.Z
                    if ([Math]::Floor($script:fase * 1.5) % 2 -eq 0) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 240 30 30))), 16, 283, 10, 10) }
                    Texto-Contorno $g 'EN DIRECTO' 'EdmundMcMillen_INTLv4' 15 32 277 (C 255 214 60) 3
                    Texto-Contorno $g "COLLARES  Pyrophina $($script:collares.P)  ·  Zaratana $($script:collares.Z)" 'EdmundMcMillen_INTLv4' 13 140 279 (C 255 236 200) 3
                }
                'zorro' {
                    $g.DrawString('ANTOJO DE SÁNDWICH', (FntP('Trebuchet MS', 8.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 246 230))), 15, 279)
                    $g.DrawString('ANTOJO DE SÁNDWICH', (FntP('Trebuchet MS', 8.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 110 60 30))), 14, 278)
                    $marco = Ruta-Redonda 170 281 170 13 10
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 236 214))), $marco)
                    if ($script:antojo -gt 0) {
                        $colA = if ($script:antojo -ge 100) { (C 220 60 60) } else { (C 236 140 60) }
                        $relleno = Ruta-Redonda 171 282 ([Math]::Max(10, 168 * $script:antojo / 100)) 11 10
                        $g.FillPath((New-Object System.Drawing.SolidBrush($colA)), $relleno); $relleno.Dispose()
                    }
                    $g.DrawPath((New-Object System.Drawing.Pen((C 150 80 40), 2)), $marco); $marco.Dispose()
                    Dibujar-Sandwich $g 370 274 0.8
                }
                'femta' {
                    # palabras de canciones de femtanyl que saltan por la pantalla
                    foreach ($pw in $script:tkPal) {
                        $st = $g.Save(); $g.TranslateTransform([float]$pw.X, [float]$pw.Y); $g.RotateTransform([float]$pw.Rot)
                        $al = [int][Math]::Min(255, $pw.T * 14)
                        Texto-Color $g $pw.Txt 'Arial Black' 20 3 0 (ARGB ([int]($al * 0.6)) 40 230 255) (ARGB 0 0 0 0) 1
                        Texto-Color $g $pw.Txt 'Arial Black' 20 0 0 (ARGB $al 255 255 255) (ARGB $al 230 20 40) 4
                        $g.Restore($st)
                    }
                    # modo breakcore: franjas de glitch por todo el panel
                    if ($script:tkFx -gt 0) {
                        for ($i = 0; $i -lt 7; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush(@((ARGB 150 230 20 40), (ARGB 110 255 255 255), (ARGB 110 40 230 255), (ARGB 200 0 0 0))[$Rnd.Next(4)])), $Rnd.Next(-60, $W), $Rnd.Next(0, $H), $Rnd.Next(60, 400), $Rnd.Next(2, 9)) }
                        if ($script:tkFx % 6 -lt 3) { Texto-Color $g 'BREAKCORE MODE' 'Arial Black' 18 470 66 (C 255 255 255) (C 230 20 40) 4 }
                    }
                    # la canción de la portada que se ve
                    $tc = "♪ $($TokenCanciones[$script:tkCd - 1])"; $tw = Ancho-Texto $tc 'Arial Black' 11
                    $g.FillRectangle([System.Drawing.Brushes]::Black, [float](572 - $tw / 2 - 6), 250, [float]($tw + 12), 20)
                    Texto-Color $g $tc 'Arial Black' 11 (572 - $tw / 2) 252 (C 255 255 255) (C 230 20 40) 1
                    # fichas y barra de HYPE
                    Texto-Color $g "TOKENS: $($script:tkFichas)" 'Consolas' 15 16 284 (C 255 255 255) (C 230 20 40) 3
                    $bpm = 174 + [int]($script:tkHype * 0.66) + $(if ($script:tkFx -gt 0) { 66 } else { 0 })
                    Texto-Color $g "BPM $bpm" 'Consolas' 15 150 284 (C 255 60 70) (C 0 0 0) 3
                    Texto-Color $g 'HYPE' 'Consolas' 12 248 286 (C 255 255 255) (C 0 0 0) 3
                    for ($i = 0; $i -lt 5; $i++) {
                        $lleno = $script:tkHype -ge ($i + 1) * 20 - 10 -or $script:tkFx -gt 0
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($lleno) { (C 230 20 40) } else { (C 50 20 24) }))), (290 + $i * 20), 287, 16, 14)
                        $g.DrawRectangle((New-Object System.Drawing.Pen((C 255 255 255), 1)), (290 + $i * 20), 287, 16, 14)
                    }
                }
                'punk' {
                    # el minirreproductor de su canal: un vídeo suyo (la canción que suena o lo que esté pasando)
                    $vx = 406; $vy = 64; $vw = 150; $vh = 84
                    $v = if ($script:kyVideo -and [Environment]::TickCount -lt $script:kyVideo.Hasta) { $script:kyVideo.N } else { 'guitarra' }
                    $vid = Ky-Gif $v
                    $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 150 46 34 30))), (Ruta-Redonda ($vx + 3) ($vy + 3) $vw ($vh + 34) 10))
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 248 240))), (Ruta-Redonda ($vx - 4) ($vy - 4) ($vw + 8) ($vh + 38) 10))
                    if ($vid) { Yt-Miniatura $g $vid.Img $vid.Info ([Environment]::TickCount) $vx $vy $vw $vh $null }
                    $dur = Ky-Duracion; $seg = $script:kyProg * $dur
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 140 0 0 0))), $vx, ($vy + $vh - 3), $vw, 3)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 0 0))), $vx, ($vy + $vh - 3), [float]($vw * $script:kyProg), 3)
                    $titulo = if ($v -eq 'guitarra') { $k.Canciones[$script:kyCancion] } else { $vid.Titulo }
                    $g.DrawString($titulo, (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 46 34 30))), (New-Object System.Drawing.RectangleF($vx, ($vy + $vh + 1), $vw, 14)))
                    $g.DrawString("▶ $(Ky-Tiempo $seg) / $(Ky-Tiempo $dur)   ·   $(Ky-Numero (12400 + $script:kyVistas)) visitas", (FntP('Segoe UI Symbol', 6.5)), (New-Object System.Drawing.SolidBrush((C 110 90 84))), $vx, ($vy + $vh + 15))
                    # la guitarra explota: destello y humo encima de Kenny
                    if ($script:kyFlash -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $script:kyFlash * 30), 255, 230, 160))), 400, 56, ($W - 400), ($H - 56)) }
                    if ($script:kyFx -gt 0) {
                        $rh = New-Object System.Random 4
                        for ($i = 0; $i -lt 8; $i++) { $q = 50 - $script:kyFx; $hx = 510 + $rh.Next(0, 90); $hy = 250 - $q * (1.5 + $rh.NextDouble()); $hr = 14 + $q * 0.7
                            if ($hy -gt 56) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB ([int]([Math]::Min(1.0, $script:kyFx / 20.0) * 120)) 80 70 70))), [float]($hx - $hr / 2), [float]$hy, [float]$hr, [float]$hr) } }
                    }
                    # concierto: focos de colores que barren el panel y "ENCORE!"
                    if ($script:kyConc -gt 0) {
                        $al = [int]([Math]::Min(1.0, $script:kyConc / 20.0) * 60)
                        $cols = @((C 110 235 140), (C 255 120 160), (C 255 220 120))
                        for ($i = 0; $i -lt 3; $i++) {
                            $ox = 120 + $i * 260; $an = [Math]::Sin($script:fase * 0.8 + $i * 2) * 0.5
                            $px1 = $ox + [Math]::Sin($an) * 300; $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$ox, 52)), (New-Object System.Drawing.PointF([float]($px1 - 70), [float]$H)), (New-Object System.Drawing.PointF([float]($px1 + 70), [float]$H)))
                            $g.FillPolygon((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, $cols[$i].R, $cols[$i].G, $cols[$i].B))), $pts)
                        }
                        if ([Math]::Floor($script:fase * 2) % 2 -eq 0) { Texto-Color $g 'ENCORE!' 'Arial Black' 22 412 196 (C 255 255 255) (C 46 34 30) 6 }
                    }
                    # botón de suscribirse (en la barra de arriba)
                    $sb = Ruta-Redonda $KyBoton[0] $KyBoton[1] $KyBoton[2] $KyBoton[3] 11
                    $g.FillPath((New-Object System.Drawing.SolidBrush($(if ($script:kySub) { (C 70 54 50) } else { (C 230 30 30) }))), $sb)
                    $g.DrawPath((New-Object System.Drawing.Pen((C 255 248 240), 1.5)), $sb); $sb.Dispose()
                    $ts = if ($script:kySub) { 'SUSCRITO 🔔' } else { 'SUSCRIBIRSE' }
                    $fs = FntP('Segoe UI Symbol', 7, [System.Drawing.FontStyle]::Bold); $tws = $g.MeasureString($ts, $fs).Width
                    $g.DrawString($ts, $fs, [System.Drawing.Brushes]::White, [float]($KyBoton[0] + $KyBoton[2] / 2 - $tws / 2), [float]($KyBoton[1] + 4))
                    # visitas, likes, guitarras rotas y el amplificador, en pastillas marrones
                    $osc = (ARGB 235 80 60 54); $bl = [System.Drawing.Color]::White
                    Yt-Pastilla $g 20 280 92 24 $osc "♥  $(Ky-Numero $script:kyLikes)" $bl 9
                    Yt-Pastilla $g 116 280 112 24 $osc "▶  $(Ky-Numero $script:kyVistas) visitas" $bl 8.5
                    Yt-Pastilla $g 232 280 56 24 $osc "⚡ $($script:kyRotas)" $bl 9
                    Yt-Pastilla $g 292 280 100 24 $osc $null $null 9
                    $g.DrawString('AMP', (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 300, 285)
                    for ($i = 0; $i -lt 8; $i++) {
                        $bh = 5 + $i * 1.5; $bx = 328 + $i * 7.5
                        $on = $script:kyAmp -ge ($i + 1) * 12.5 - 6
                        $colA = if ($i -ge 6) { (C 255 60 60) } elseif ($i -ge 4) { (C 255 210 60) } else { (C 110 235 140) }
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($on) { $colA } else { (C 120 100 94) }))), [float]$bx, [float](298 - $bh), 5, [float]$bh)
                    }
                }
                'pizza' {
                    # la pizza de Kevin en su plato (o el plato vacío esperando al repartidor)
                    Dibujar-Pizza $g $PizzaX $PizzaY $PizzaR $script:pzTrozos $script:pzQueso
                    if ($script:pzTrozos -le 0 -and ([Math]::Floor([Environment]::TickCount / 400) % 2 -eq 0)) {
                        Texto-Contorno $g 'PIZZA EN' 'Comic Sans MS' 11 ($PizzaX - 30) ($PizzaY - 18) (C 255 110 200) 3
                        Texto-Contorno $g 'CAMINO...' 'Comic Sans MS' 11 ($PizzaX - 32) ($PizzaY - 2) (C 255 110 200) 3
                    }
                    # rabia: el lienzo se pone rojo y el borde arde
                    if ($script:pzFx -gt 0) {
                        $al = [int]([Math]::Min(1.0, $script:pzFx / 20.0) * (60 + [Math]::Sin($script:fase * 3) * 30))
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 230, 30, 0))), 414, 90, 334, 172)
                        $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([Math]::Min(255, $al * 3), 255, 140, 0), 4)), 412, 88, 338, 176)
                    }
                    # trozos de pizza (o brasas) cayendo
                    foreach ($t in $script:pzLluvia) {
                        if ($t.Fuego) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 200 255 ([int](120 + ($t.A % 100))) 0))), [float]$t.X, [float]$t.Y, 6, 9) }
                        else { Dibujar-Trozo $g $t.X $t.Y 18 $t.A }
                    }
                    # el grito: DON'T TOUCH MY PIZZA!
                    if ($script:pzGrito) {
                        $q = 30 - $script:pzGrito.T; $esc = if ($q -lt 4) { 0.4 + $q * 0.2 } else { 1.0 }
                        $al = [int][Math]::Min(255, $script:pzGrito.T * 20)
                        $st = $g.Save(); $g.TranslateTransform([float](580 + $Rnd.Next(-3, 4)), [float](120 + $Rnd.Next(-2, 3))); $g.RotateTransform(-6); $g.ScaleTransform([float]$esc, [float]$esc)
                        $tw = Ancho-Texto $script:pzGrito.Txt 'Impact' 30
                        Texto-Color $g $script:pzGrito.Txt 'Impact' 30 (-$tw / 2) (-20) (ARGB $al 230 30 30) (ARGB $al 255 255 255) 8
                        $g.Restore($st)
                    }
                    # pizzas comidas, trozos que quedan y barra de enfado
                    Texto-Contorno $g "PIZZAS: $($script:pzComidas)" 'Comic Sans MS' 13 16 278 (C 70 200 40) 4
                    for ($i = 0; $i -lt 8; $i++) {
                        if ($i -lt $script:pzTrozos) { Dibujar-Trozo $g (134 + $i * 14) 293 12 180 }
                        else { $g.DrawPolygon((New-Object System.Drawing.Pen((ARGB 120 60 60 60), 1)), [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float](134 + $i * 14), 286)), (New-Object System.Drawing.PointF([float](128 + $i * 14), 299)), (New-Object System.Drawing.PointF([float](140 + $i * 14), 299)))) }
                    }
                    Texto-Contorno $g 'ENFADO' 'Comic Sans MS' 11 250 281 (C 230 40 40) 3
                    $g.FillRectangle([System.Drawing.Brushes]::White, 310, 285, 86, 12)
                    if ($script:pzEnfado -gt 0) {
                        $colE = if ($script:pzFx -gt 0) { @((C 255 140 0), (C 230 30 30))[[int]($script:fase * 2) % 2] } else { (C 230 40 40) }
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush($colE)), 310, 285, [int](86 * $script:pzEnfado / 100), 12)
                    }
                    $g.DrawRectangle((New-Object System.Drawing.Pen((C 20 20 20), 2)), 310, 285, 86, 12)
                }
                'pop' {
                    # peces neón nadando
                    foreach ($pz in $script:peces) { Dibujar-Tetra-Pez $g $pz.X ($pz.Y + [Math]::Sin($pz.F) * 3) $pz.E $pz.F }
                    # notificación de mensaje de "neems"
                    if ($script:popNoti) {
                        $n = $script:popNoti; $dy = if ($n.T -gt 74) { (80 - $n.T) * 8 - 48 } elseif ($n.T -lt 8) { - (8 - $n.T) * 6 } else { 0 }
                        $nr = Ruta-Redonda 420 (82 + $dy) 196 40 10
                        $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 235 24 12 40))), $nr); $g.DrawPath((New-Object System.Drawing.Pen((C 90 230 250), 1.5)), $nr); $nr.Dispose()
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 236 196 140))), 428, (88 + $dy), 28, 28)
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 120 80 50))), 430, (88 + $dy), 10, 14); $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 120 80 50))), 444, (88 + $dy), 10, 14)
                        $g.FillEllipse([System.Drawing.Brushes]::Black, 438, (102 + $dy), 7, 5)
                        $g.DrawString('neems', (FntP('Trebuchet MS', 8.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 255 92 190))), 462, (84 + $dy))
                        $g.DrawString($n.Txt, (FntP('Trebuchet MS', 8.5)), [System.Drawing.Brushes]::White, 462, (100 + $dy))
                    }
                    # rayas de tele, banda de "tracking" y letras de la cinta (OSD)
                    $sl = New-Object System.Drawing.Pen((ARGB 34 0 0 0), 1); for ($y = 58; $y -lt 276; $y += 3) { $g.DrawLine($sl, 410, $y, $W, $y) }; $sl.Dispose()
                    $tky = 58 + (([Environment]::TickCount / 30) % 260)
                    if ($tky -lt 270) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 26 255 255 255))), 410, [float]$tky, ($W - 410), 6) }
                    $seg = [int](([Environment]::TickCount - $script:popIni) / 1000)
                    $osd = FntP('Consolas', 9.5, [System.Drawing.FontStyle]::Bold)
                    $g.DrawString(('PLAY ▶   SP {0}:{1:00}:{2:00}' -f [int]($seg / 3600), [int](($seg / 60) % 60), ($seg % 60)), $osd, (New-Object System.Drawing.SolidBrush((ARGB 230 255 255 255))), 416, 60)
                    $g.DrawString('SEP. 29 2021', $osd, (New-Object System.Drawing.SolidBrush((ARGB 200 255 214 120))), 668, 258)
                    if ($script:popFx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ($script:popFx * 12) 255 92 190))), 410, 56, ($W - 410), 220) }
                    # mensajes y No molestar
                    Texto-Color $g "MENSAJES: $($script:popMsgs)" 'Trebuchet MS' 15 18 284 (C 255 255 255) (C 255 92 190) 3
                    $dnd = if ($script:popDND) { 'NO MOLESTAR: SÍ' } else { 'NO MOLESTAR: NO' }
                    Texto-Color $g $dnd 'Trebuchet MS' 13 168 286 $(if ($script:popDND) { (C 90 230 250) } else { (C 255 214 120) }) (C 30 10 50) 3
                    if ($script:popDND) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 90 230 250))), 330, 286, 16, 16); $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 30 14 52))), 335, 283, 15, 15) }
                }
                'gran' {
                    $e = $script:gr
                    # marco verde del monitor, líneas de pantalla y la etiqueta de la cámara del laboratorio
                    $sl = New-Object System.Drawing.Pen((ARGB 26 0 0 0), 1); for ($y = 62; $y -lt 266; $y += 3) { $g.DrawLine($sl, 414, $y, 748, $y) }; $sl.Dispose()
                    if ($e -and $e.Fx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int]($e.Fx * 9)) $e.FxCol.R $e.FxCol.G $e.FxCol.B))), 414, 62, 334, 204) }
                    $g.DrawRectangle((New-Object System.Drawing.Pen((C 32 208 44), 2)), 413, 61, 336, 206)
                    $osd = FntP('Consolas', 8, [System.Drawing.FontStyle]::Bold)
                    if ([int]([Environment]::TickCount / 600) % 2 -eq 0) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 230 40 60))), 420, 68, 8, 8) }
                    $g.DrawString('CAM 07 · CENTRAL TOWER', $osd, (New-Object System.Drawing.SolidBrush((C 200 255 205))), 431, 65)
                    $g.DrawString('ANTIHUMAN INC.', $osd, (New-Object System.Drawing.SolidBrush((C 32 208 44))), 654, 252)
                    # registro de sujetos de prueba
                    if ($e) {
                        $pc = if ($e.Sujetos -gt 0) { [int](100 * $e.Exitos / $e.Sujetos) } else { 0 }
                        Texto-Color $g "SUJETOS: $($e.Sujetos)" 'Bahnschrift' 14 18 284 (C 200 255 205) (C 0 0 0) 3
                        Texto-Color $g "FURRIES: $($e.Exitos)" 'Bahnschrift' 14 150 284 (C 32 208 44) (C 0 0 0) 3
                        Texto-Color $g "ÉXITO: $pc %" 'Bahnschrift' 14 284 284 $(if ($pc -ge 60 -or $e.Sujetos -eq 0) { (C 200 255 205) } else { (C 255 110 130) }) (C 0 0 0) 3
                    }
                }
                'evil' {
                    $e = $script:es; $ahora = [Environment]::TickCount
                    $cerca = if ($e) { 1.0 - $e.Vis / 100.0 } else { 0.0 }
                    # cuanto más cerca, más rojo se pone todo (en modo seguro sin parpadeo)
                    $pulso = if ($script:aj.Epilepsia) { 0.5 } else { 0.5 + 0.5 * [Math]::Sin($ahora / 260.0) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int](70 * $cerca * $cerca * (0.6 + 0.4 * $pulso)), 160, 0, 10))), 404, 56, ($W - 404), ($H - 56))
                    # aviso de la alarma y de la carga
                    if ($e -and $e.Fase -eq 'aviso') {
                        $on = $script:aj.Epilepsia -or ([int]($ahora / 300) % 2 -eq 0)
                        if ($on) { $tw = Ancho-Texto '⚠ STALL ⚠' 'Arial Black' 26; Texto-Color $g '⚠ STALL ⚠' 'Arial Black' 26 (580 - $tw / 2) 64 (C 255 210 40) (C 0 0 0) 6 }
                        Texto-Color $g '¡HAZ CLIC EN ÉL PARA BLOQUEARLO!' 'Arial' 11 470 102 (C 255 255 255) (C 0 0 0) 4
                    } elseif ($e -and $e.Fase -eq 'carga') {
                        Texto-Color $g '¡¡CARGA!!' 'Arial Black' 24 516 64 (C 230 30 40) (C 0 0 0) 6
                    }
                    # el susto: la cara roja ocupa toda la pantalla (en modo seguro, Sin-Destellos lo apaga)
                    if ($e -and $e.Fx -gt 0) {
                        if (-not $script:esSusto) { $script:esSusto = Cargar-Img $k.Susto }
                        $al = [Math]::Min(1.0, $e.Fx / 10.0)
                        if ($script:esSusto) {
                            $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$al
                            $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                            $z = 1.0 + (1 - $al) * 0.3; $sw = $W * $z; $sh = $sw * $script:esSusto.Height / $script:esSusto.Width; if ($sh -lt $H * $z) { $sh = $H * $z; $sw = $sh * $script:esSusto.Width / $script:esSusto.Height }
                            $g.DrawImage($script:esSusto, (New-Object System.Drawing.Rectangle([int]($W / 2 - $sw / 2 + $Rnd.Next(-6, 7)), [int]($H / 2 - $sh / 2 + $Rnd.Next(-4, 5)), [int]$sw, [int]$sh)), 0, 0, $script:esSusto.Width, $script:esSusto.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
                            $ia.Dispose()
                        }
                    }
                    # abajo: distancia, rebotes, sustos y bloqueos
                    $osc = (ARGB 235 22 10 12); $cl = (C 236 220 220)
                    Yt-Pastilla $g 16 280 170 24 $osc $null $null 8
                    $g.DrawString('DISTANCIA', (FntP('Arial', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 26, 285)
                    $dv = if ($e) { $e.Vis } else { 100 }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 16 18))), 92, 287, 86, 10)
                    $colD = if ($dv -lt 30) { (C 230 30 40) } elseif ($dv -lt 60) { (C 230 140 40) } else { (C 120 200 120) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush($colD)), 92, 287, [float](86 * $dv / 100.0), 10)
                    $fase = if (-not $e) { '' } elseif ($e.Fase -eq 'aviso') { '⚠ STALL' } elseif ($e.Fase -eq 'carga') { '¡CARGA!' } else { $cada = $(if ($e.Gigante) { 4 } else { 6 }); "rebote $($e.Rebotes % $cada)/$cada" }
                    Yt-Pastilla $g 190 280 88 24 $osc $fase $cl 8
                    Yt-Pastilla $g 282 280 116 24 $osc "😱 $(if ($e) { $e.Sustos } else { 0 })   🛡 $(if ($e) { $e.Bloqueos } else { 0 })" $cl 8.5
                    if ($e -and $e.Gigante) { Texto-Color $g 'GIGANTE' 'Arial Black' 11 690 64 (C 255 210 40) (C 0 0 0) 4 }
                }
                'niebla' {
                    $e = $script:sf
                    # niebla de siempre, suave, por la escena
                    Pintar-Niebla $g 404 $W $H 0.35
                    # niebla espesa (cada 6 apps y al salir de la intro, que se va despejando)
                    $q = Sf-Espesor
                    if ($q -gt 0) {
                        Pintar-Niebla $g 0 $W $H $q
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]($e.NieblaTope * $q), 255, 186, 244))), 0, 0, $W, $H)
                    }
                    # abajo: la barra de EXISTENCIA, manos que le han atravesado y sustos/corazones de Orange Cat
                    $osc = (ARGB 225 50 20 86); $cl = (C 255 225 250)
                    Yt-Pastilla $g 16 280 196 24 $osc $null $null 8
                    $g.DrawString('EXISTENCIA', (FntP('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 24, 285)
                    $ev = if ($e) { $e.Vis } else { 70 }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 30 10 50))), 100, 287, 104, 10)
                    $colE = if ($ev -lt 20) { (C 150 120 160) } elseif ($ev -lt 50) { (C 230 140 220) } else { (C 255 120 240) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush($colE)), 100, 287, [float](104 * $ev / 100.0), 10)
                    Yt-Pastilla $g 218 280 86 24 $osc "manos: $(if ($e) { $e.Manos } else { 0 })" $cl 8.5
                    Yt-Pastilla $g 310 280 88 24 $osc "♥ cat: $(if ($e) { $e.Gato } else { 0 })" $cl 8.5
                }
                'abismo' {
                    $e = $script:nn
                    # los hilos del campo de fuerza (más fuertes cuando está feliz)
                    Dibujar-Campo $g 410 58 346 212 $(if ($e -and $e.Fx -gt 0) { 110 } else { 45 })
                    # su dibujo en la pared: papel con celo y su cara del anime dentro
                    $dx = 416; $dy = 66; $dw = 156; $dh = 98
                    $st = $g.Save(); $g.TranslateTransform([float]($dx + $dw / 2), [float]($dy + $dh / 2)); $g.RotateTransform(-3)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), [float](-$dw / 2 + 4), [float](-$dh / 2 + 4), [float]($dw + 8), [float]($dh + 22))
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 246 236 212))), [float](-$dw / 2 - 4), [float](-$dh / 2 - 4), [float]($dw + 8), [float]($dh + 22))
                    $cara = if ($e -and $e.Cara -and [Environment]::TickCount -lt $e.CaraHasta) { $e.Cara } else { 'chulo' }
                    $c = Nn-Gif $cara
                    if ($c) { Gif-Frame $c.Img $c.Info ([Environment]::TickCount); $g.DrawImage($c.Img, [float](-$dw / 2), [float](-$dh / 2), [float]$dw, [float]$dh) }
                    $g.DrawString('Nanachi ♪', (FntP('Segoe Print', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 120 80 60))), [float](-$dw / 2), [float]($dh / 2))
                    $celo = New-Object System.Drawing.SolidBrush((ARGB 150 255 240 170))
                    $g.FillRectangle($celo, [float](-$dw / 2 - 12), [float](-$dh / 2 - 8), 30, 10); $g.FillRectangle($celo, [float]($dw / 2 - 18), [float](-$dh / 2 - 8), 30, 10); $celo.Dispose()
                    $g.Restore($st)
                    # el muñeco de pájaro que Nanachi cosió para Mitty, delante de ella
                    Dibujar-Muneco $g 520 240
                    # la olla del estofado, con vapor y burbujas
                    if (-not $script:nnOlla) { $script:nnOlla = Cargar-Img $k.Estofado }
                    if ($script:nnOlla) { $g.DrawImage($script:nnOlla, 430, 204, 92, 69) }
                    $t = [Environment]::TickCount / 1000.0; $va = if ($e -and $e.Vapor -gt 0) { 150 } else { 70 }
                    for ($i = 0; $i -lt 3; $i++) {
                        $vx = 458 + $i * 16; $vp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($va, 240, 240, 240), 3); $vp.StartCap = 'Round'; $vp.EndCap = 'Round'
                        $g.DrawBezier($vp, [float]$vx, 206, [float]($vx + 8 * [Math]::Sin($t * 2 + $i)), 194, [float]($vx - 8 * [Math]::Sin($t * 2 + $i)), 182, [float]$vx, 170); $vp.Dispose()
                    }
                    # ingredientes ya echados (puntitos) encima de la olla
                    if ($e) { for ($i = 0; $i -lt 5; $i++) { $g.FillEllipse((New-Object System.Drawing.SolidBrush($(if ($i -lt $e.Ing) { (C 236 170 190) } else { (ARGB 120 60 44 34) }))), [float](446 + $i * 13), 196, 9, 9) } }
                    # abajo: estofados servidos, medidor de MULLIDO y la profundidad
                    $osc = (ARGB 230 64 46 32); $cl = (C 252 240 214)
                    $ne = if ($e) { $e.Estofados } else { 0 }
                    Yt-Pastilla $g 16 280 110 24 $osc "🍲  $ne $(if ($ne -eq 1) { 'estofado' } else { 'estofados' })" $cl 8.5
                    Yt-Pastilla $g 132 280 152 24 $osc $null $null 8
                    $g.DrawString('MULLIDO', (FntP('Trebuchet MS', 7.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($cl)), 140, 285)
                    $mv = if ($e) { $e.Mullido } else { 0 }
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 40 28 20))), (Ruta-Redonda 196 287 80 10 5))
                    if ($mv -gt 1) { $g.FillPath((New-Object System.Drawing.SolidBrush((C 236 170 190))), (Ruta-Redonda 196 287 ([Math]::Max(10.0, 80.0 * $mv / 100.0)) 10 5)) }
                    Yt-Pastilla $g 290 280 108 24 $osc '⬇ 4ª capa · 7.100 m' $cl 7.5
                }
                'enfosi' {
                    $e = $script:ef
                    if ($e) {
                        # vida de la estatua
                        $fr = [Math]::Max(0.0, $e.HP / [double]$e.HPMax)
                        $cv = if ($fr -gt 0.5) { (C 90 200 60) } elseif ($fr -gt 0.25) { (C 240 180 30) } else { (C 230 40 40) }
                        Texto-Color $g 'ESTATUA' 'Arial Black' 9 410 60 (C 255 255 255) (C 20 20 20) 3
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 170 0 0 0))), 408, 76, 118, 12)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush($cv)), 410, 78, [int](114 * $fr), 8)
                        $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1)), 408, 76, 118, 12)
                        # strikes: tres caritas (una X roja por cada strike)
                        for ($i = 0; $i -lt 3; $i++) { Dibujar-Carita $g (704 + $i * 22) 74 9 ($i -ge $e.Strikes) }
                        # vida de los Enphosians descubiertos y de los jefes
                        if ($e.W -and $e.W.Estado -in @('revelado', 'ataca')) {
                            $aw = $script:actores['W']
                            for ($i = 0; $i -lt $e.W.Vida; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 40 40))), [float]($e.W.X + 4 + $i * 9), [float]($aw.Rect[1] - 4), 7, 7); $g.DrawRectangle((New-Object System.Drawing.Pen((C 20 20 20), 1)), [float]($e.W.X + 4 + $i * 9), [float]($aw.Rect[1] - 4), 7, 7) }
                        }
                        # explosión negra al descubrir un Enphosian
                        if ($e.Negro -gt 0) {
                            $q = 16 - $e.Negro
                            for ($k2 = 0; $k2 -lt 3; $k2++) { $rr = 10 + $q * 6 + $k2 * 10; $g.DrawEllipse((New-Object System.Drawing.Pen((ARGB ([int][Math]::Max(0, 230 - $q * 14)) 0 0 0), 8)), [float]($e.NX - $rr), [float]($e.NY - $rr), [float](2 * $rr), [float](2 * $rr)) }
                        }
                        # el Ojo de Enphoso se acerca
                        if ($e.Ojo -gt 0) {
                            $q = $e.Ojo; $sz = 40 + $q * 1.15; $al = [float]([Math]::Min(1.0, $q / 20.0) * 0.95)
                            $ox = 720 - $q * 0.75; $oy = 150
                            $oj = Enfosi-Img 'ojo.png'
                            if ($oj) {
                                $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = $al
                                $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
                                $g.DrawImage($oj, (New-Object System.Drawing.Rectangle([int]($ox - $sz / 2), [int]($oy - $sz / 2), [int]$sz, [int]$sz)), 0, 0, $oj.Width, $oj.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia); $ia.Dispose()
                            }
                            $tt = Enfosi-Img 'enphoso_titulo.png'
                            if ($tt -and (([Environment]::TickCount / 350) % 2) -lt 1) { $g.DrawImage($tt, 560, 92, 150, [float]($tt.Height * 150 / $tt.Width)) }
                        }
                        # flash rojo de strike
                        if ($e.Rojo -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB ([int][Math]::Min(200, $e.Rojo * 14)) 220 20 20))), 400, 56, ($W - 400), 218) }
                        # cartel de oleada
                        if ($e.Banner) {
                            $bi = Enfosi-Img $e.Banner.Img
                            if ($bi) { $q = 55 - $e.Banner.T; $es = if ($q -lt 4) { $q / 4.0 * 1.1 } elseif ($q -lt 7) { 1.1 - ($q - 4) / 30.0 } else { 1.0 }; $bw = 300 * [Math]::Max(0.05, $es); $bh = $bi.Height * $bw / $bi.Width; $g.DrawImage($bi, [float](585 - $bw / 2), [float](150 - $bh / 2), [float]$bw, [float]$bh) }
                        }
                        # rango al acabar la oleada, o la pantalla de GAME OVER
                        if ($e.Cartel) {
                            $ci = Enfosi-Img $e.Cartel.Img
                            if ($ci) {
                                if ($e.Cartel.Img -eq 'gameover.jpg') {
                                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 0 0))), 400, 56, ($W - 400), 218)
                                    $ch = 210; $cw = $ci.Width * $ch / $ci.Height; $g.DrawImage($ci, [float](585 - $cw / 2), 60, [float]$cw, [float]$ch)
                                } else {
                                    $q = $e.Cartel.Max - $e.Cartel.T; $es = [Math]::Max(0.05, [Math]::Min(1.0, $q / 5.0))
                                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 0 0 0))), 400, 56, ($W - 400), 218)
                                    $cw = 260 * $es; $ch = $ci.Height * $cw / $ci.Width; $g.DrawImage($ci, [float](585 - $cw / 2), [float](160 - $ch / 2), [float]$cw, [float]$ch)
                                }
                            }
                        }
                        # marcador: oleada, puntos, Bintar
                        Texto-Color $g "OLEADA $($e.Ola)/7" 'Arial Black' 14 16 284 (C 255 255 255) (C 20 20 20) 4
                        Texto-Color $g "PUNTOS $($e.Puntos)" 'Arial Black' 12 140 286 (C 255 214 60) (C 20 20 20) 4
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 250 200 40))), 268, 286, 16, 16); $g.DrawEllipse((New-Object System.Drawing.Pen((C 120 80 0), 1.5)), 268, 286, 16, 16)
                        $g.DrawString('B', (FntP('Arial Black', 7)), (New-Object System.Drawing.SolidBrush((C 120 80 0))), 271, 287)
                        Texto-Color $g "x$($e.Bintar)" 'Arial Black' 12 288 286 (C 255 255 255) (C 20 20 20) 4
                        if ($e.Sobber) { Texto-Color $g 'SOBBER' 'Arial Black' 12 336 286 (C 110 150 255) (C 20 20 20) 4 }
                    }
                }
                'teto' {
                    # pajaritos posados o volando
                    foreach ($p in $script:pajaros) { Dibujar-Pajaro $g $p.X $p.Y 1.0 ($p.Est -in @('vuela', 'huye')) $p.F $p.Dir }
                    # contador de pajaritos (cinco = ¡birdbrain!)
                    Texto-Contorno $g 'PAJARITOS' 'Arial Black' 13 18 302 (C 255 255 255) 4
                    $vivos = @($script:pajaros | Where-Object { $_.Est -in @('posado', 'cabeza') }).Count
                    for ($i = 0; $i -lt 5; $i++) {
                        if ($i -lt $vivos) { Dibujar-Pajaro $g (124 + $i * 28) 318 0.8 $false 0 1 }
                        else { $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 90 176 24 48))), (116 + $i * 28), 306, 14, 9) }
                    }
                    if ($script:birdbrains -gt 0) { Texto-Contorno $g "BIRDBRAIN x$($script:birdbrains)" 'Arial Black' 12 268 303 (C 246 204 60) 4 }
                }
                'pressure' {
                    # mostrador de la tienda, delante de Sebastian
                    $mx = 426; $my = 222; $mw = $W - $mx
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 92 102 112))), $mx, $my, $mw, 6)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 150 162 172))), $mx, $my, $mw, 2)
                    $fr = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle($mx, ($my + 6), $mw, 40)), (C 40 46 54), (C 16 20 26), 90)
                    $g.FillRectangle($fr, $mx, ($my + 6), $mw, 40); $fr.Dispose()
                    foreach ($rx in @(($mx + 8), ($mx + $mw / 2), ($W - 12))) { foreach ($ry in @(($my + 12), ($my + 30))) { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 110 120 130))), [float]$rx, [float]$ry, 4, 4) } }
                    # objetos a la venta encima del mostrador
                    Dibujar-Objeto $g 'linterna' 436 ($my - 22) 24
                    Dibujar-Objeto $g 'pilas' 462 ($my - 18) 20
                    Dibujar-Objeto $g 'botiquin' 704 ($my - 24) 26
                    Dibujar-Objeto $g 'splorg' 732 ($my - 20) 22
                    # cartel: se enciende cuando la tienda está abierta
                    $on = $script:modoTienda -or ([Math]::Floor([Environment]::TickCount / 900) % 2 -eq 0)
                    $cl = if ($script:modoTienda) { (C 255 190 70) } elseif ($on) { (C 120 200 210) } else { (C 60 90 96) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 8 10 14))), 520, ($my + 10), 160, 22)
                    $g.DrawRectangle((New-Object System.Drawing.Pen($cl, 1)), 520, ($my + 10), 160, 22)
                    $cartel = if ($script:modoTienda) { "SEBASTIAN'S SHOP · OPEN" } else { "SEBASTIAN'S SHOP" }
                    $tw = Ancho-Texto $cartel 'Bahnschrift' 12
                    Texto-Contorno $g $cartel 'Bahnschrift' 12 (600 - $tw / 2) ($my + 13) $cl 2
                    # destello del Flash Beacon y enfado (GET. OUT!)
                    if ($script:destello -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $script:destello * 22), 255, 255, 240))), 400, 56, ($W - 400), ($H - 56)) }
                    if ($script:enfadoFx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]([Math]::Min(1.0, $script:enfadoFx / 10.0) * 120), 200, 0, 0))), 0, 0, $W, $H) }
                    # investigación y los últimos objetos comprados
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 120 230 240))), 18, 279, 7, 14); $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 220 240 245))), 16, 277, 11, 3)
                    Texto-Contorno $g "INVESTIGACIÓN  $($script:investigacion)" 'Bahnschrift' 14 32 276 (C 220 240 245) 3
                    for ($i = 0; $i -lt 5; $i++) {
                        $sx = 222 + $i * 34
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 160 10 14 18))), $sx, 272, 30, 30)
                        $g.DrawRectangle((New-Object System.Drawing.Pen((C 70 190 200), 1)), $sx, 272, 30, 30)
                        if ($i -lt $script:inventario.Count) { Dibujar-Objeto $g $script:inventario[$i] ($sx + 2) 274 26 }
                    }
                }
                'dod' {
                    # Pursuer invisible: solo se ven sus ojos verdes
                    if ($script:acechando) {
                        $al = [int](40 + [Math]::Sin([Environment]::TickCount / 300.0) * 30)
                        foreach ($ex in @(590, 618)) { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 60, 255, 190))), $ex, 92, 14, 9) }
                    }
                    # aullido: ondas que se expanden
                    foreach ($o in $script:ondas) {
                        $al = [Math]::Max(0, [Math]::Min(255, $o.T * 8))
                        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 120, 255, 200), 4)
                        $g.DrawEllipse($pen, [float](605 - $o.R), [float](130 - $o.R * 0.6), [float](2 * $o.R), [float](1.2 * $o.R)); $pen.Dispose()
                    }
                    # zarpazos
                    foreach ($z in $script:zarpas) {
                        $al = [Math]::Max(0, [Math]::Min(255, $z.T * 10))
                        $st = $g.Save(); $g.TranslateTransform([float]$z.X, [float]$z.Y); $g.RotateTransform([float]$z.A)
                        foreach ($dx in @(-14, 0, 14)) {
                            $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 120, 0, 0), 7)), [float]$dx, -40, [float]($dx + 10), 40)
                            $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 255, 70, 60), 3)), [float]$dx, -40, [float]($dx + 10), 40)
                        }
                        $g.Restore($st)
                    }
                    foreach ($o in $script:gotas) { $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([Math]::Min(255, $o.T * 10), 190, 10, 20))), [float]$o.X, [float]$o.Y, 6, 8) }
                    if ($script:rojoFx -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($script:rojoFx * 14, 200, 0, 0))), 0, 0, $W, $H) }
                    # presas y estamina
                    Texto-Contorno $g "PRESAS: $($script:presas)" 'Arial Black' 14 16 276 (C 255 80 70) 3
                    Texto-Contorno $g 'ESTAMINA' 'Arial Black' 11 140 279 (C 120 255 200) 3
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 10 30 22))), 222, 281, 160, 11)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 40 220 150))), 222, 281, [int](160 * $script:estamina / 110), 11)
                    $g.DrawRectangle((New-Object System.Drawing.Pen((C 0 130 91), 1.5)), 222, 281, 160, 11)
                }
                'mew' {
                    # fase 2: el callejón late en rojo
                    if ($script:gFase2 -and $script:gVivo) {
                        $al = [int](45 + [Math]::Sin($script:fase * 2) * 30)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 200, 20, 20))), 400, 56, ($W - 400), ($H - 56))
                    }
                    # barra de vida de jefa con calavera
                    $hx = 432; $hy = 62; $hw = 314
                    $placa = Ruta-Redonda ($hx - 4) ($hy - 3) ($hw + 8) 28 12
                    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 24, 18, 20))), $placa)
                    $g.DrawPath((New-Object System.Drawing.Pen((C 120 40 35), 2.5)), $placa); $placa.Dispose()
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 240 228 200))), ($hx), ($hy), 22, 22)
                    $g.FillEllipse([System.Drawing.Brushes]::Black, ($hx + 5), ($hy + 7), 5, 6); $g.FillEllipse([System.Drawing.Brushes]::Black, ($hx + 12), ($hy + 7), 5, 6)
                    $g.FillRectangle([System.Drawing.Brushes]::Black, ($hx + 8), ($hy + 16), 6, 2)
                    $bx = $hx + 28; $bw = $hw - 32
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 22 22))), $bx, ($hy + 3), $bw, 16)
                    $frac = if ($script:gMax -gt 0) { [Math]::Max(0, $script:gHP) / $script:gMax } else { 0 }
                    $colVida = if ($script:gFase2) { (C 240 90 30) } else { (C 200 35 35) }
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush($colVida)), $bx, ($hy + 3), [int]($bw * $frac), 16)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 255, 255))), $bx, ($hy + 3), [int]($bw * $frac), 5)
                    $etq = if (-not $script:gVivo) { 'GUILLOTINA  DERROTADA' } elseif ($script:gFase2) { "¡GUILLOTINA FURIOSA!  $($script:gHP)/$($script:gMax)" } else { "GUILLOTINA  $($script:gHP)/$($script:gMax)" }
                    Texto-Contorno $g $etq 'EdmundMcMillen_INTLv4' 14 ($bx + 6) ($hy + 2) (C 255 250 235) 3
                    # radio y gatos engullidos
                    Texto-Contorno $g 'WMEW 99.9' 'EdmundMcMillen_INTLv4' 15 16 277 (C 215 75 60) 3
                    Texto-Contorno $g "GATOS ENGULLIDOS: $($script:gComidos)" 'EdmundMcMillen_INTLv4' 14 128 278 (C 240 228 200) 3
                }
                'oeste' {
                    # agujeros de bala que se van borrando
                    foreach ($ag in $script:agujeros2) {
                        $al = [int][Math]::Min(255, $ag.T * 3)
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]($al * 0.6), 120, 90, 60))), [float]($ag.X - 10), [float]($ag.Y - 10), 20, 20)
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($al, 10, 6, 4))), [float]($ag.X - 5), [float]($ag.Y - 5), 10, 10)
                        $gr = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 40, 24, 12), 1.5)
                        foreach ($an in @(20, 110, 200, 290)) { $ra = $an * [Math]::PI / 180; $g.DrawLine($gr, [float]$ag.X, [float]$ag.Y, [float]($ag.X + [Math]::Cos($ra) * 13), [float]($ag.Y + [Math]::Sin($ra) * 13)) }
                        $gr.Dispose()
                    }
                    # buitres en círculos y polvo que se lleva el viento
                    $tz = [Environment]::TickCount / 1000.0
                    Dibujar-Buitre $g (478 + [Math]::Cos($tz * 0.55) * 46) (84 + [Math]::Sin($tz * 0.55) * 10) 1.0 ($tz * 4)
                    Dibujar-Buitre $g (452 + [Math]::Cos($tz * 0.4 + 2) * 30) (130 + [Math]::Sin($tz * 0.4 + 2) * 7) 0.7 ($tz * 4 + 1)
                    for ($i = 0; $i -lt 9; $i++) {
                        $px = 410 + (($tz * (30 + $i * 4) + $i * 53) % 350); $py = 196 + (($i * 17) % 56) + [Math]::Sin($tz * 2 + $i) * 4
                        $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 100 255 222 170))), [float]$px, [float]$py, 2.4, 2.4)
                    }
                    # planta rodadora
                    if ($script:tumbX -gt 360) { Dibujar-Rodadora $g $script:tumbX (234 - [Math]::Abs([Math]::Sin($script:tumbX / 28.0)) * 14) 15 ($script:tumbX * 4) }
                    # duelo: franjas de cine, "¿PREPARADO?" y "DRAW!"
                    if ($script:duelo) {
                        $d = $script:duelo
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 230 8 4 6))), 400, 56, ($W - 400), 26)
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 230 8 4 6))), 400, 232, ($W - 400), 26)
                        if ($d.Fase -eq 'espera') {
                            if ((([Environment]::TickCount / 400) % 2) -lt 1) { Texto-Color $g '¿PREPARADO?' 'EdmundMcMillen_INTLv4' 20 520 58 (C 255 214 120) (C 60 20 10) 4 }
                            Texto-Color $g 'NO HAGAS CLIC TODAVÍA' 'EdmundMcMillen_INTLv4' 13 506 236 (C 250 236 205) (C 0 0 0) 3
                        } elseif ($d.Fase -eq 'draw') {
                            $st = $g.Save(); $g.TranslateTransform(560, 150); $g.RotateTransform(-8); $e = 1.4 - [Math]::Min(0.4, $d.T * 0.1); $g.ScaleTransform([float]$e, [float]$e)
                            Texto-Color $g 'DRAW!' 'EdmundMcMillen_INTLv4' 64 (-110) (-44) (C 235 46 34) (C 255 220 90) 10
                            $g.Restore($st)
                            Texto-Color $g '¡HAZ CLIC EN ZODIAC!' 'EdmundMcMillen_INTLv4' 13 512 236 (C 255 214 120) (C 0 0 0) 3
                        }
                    }
                    # fogonazo del disparo
                    if ($script:fogonazo -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($script:fogonazo * 30, 255, 240, 180))), 400, 56, ($W - 400), ($H - 56)) }
                    # tambor del revólver con las 6 balas
                    $cx = 722; $cy = 94; $rr = 26
                    $st = $g.Save(); $g.TranslateTransform([float]$cx, [float]$cy); $g.RotateTransform([float]$script:rotTambor)
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 74 72 80))), -$rr, -$rr, (2 * $rr), (2 * $rr))
                    $g.DrawEllipse((New-Object System.Drawing.Pen((C 28 26 30), 3)), -$rr, -$rr, (2 * $rr), (2 * $rr))
                    for ($i = 0; $i -lt 6; $i++) {
                        $an = $i * [Math]::PI / 3; $px = [Math]::Cos($an) * $rr * 0.58; $py = [Math]::Sin($an) * $rr * 0.58; $cr = $rr * 0.3
                        if ($i -lt $script:balas) {
                            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 222 178 70))), [float]($px - $cr), [float]($py - $cr), [float](2 * $cr), [float](2 * $cr))
                            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 196 110 62))), [float]($px - $cr * 0.5), [float]($py - $cr * 0.5), [float]$cr, [float]$cr)
                        } else { $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 18 16 20))), [float]($px - $cr), [float]($py - $cr), [float](2 * $cr), [float](2 * $cr)) }
                    }
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 40 38 44))), -4, -4, 8, 8)
                    $g.Restore($st)
                    # cartuchera de cuero con las 6 balas y el marcador de duelos
                    $cin = Ruta-Redonda 10 280 150 26 6
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 110 60 30))), $cin); $g.DrawPath((New-Object System.Drawing.Pen((C 44 22 8), 2)), $cin); $cin.Dispose()
                    $cos = New-Object System.Drawing.Pen((ARGB 150 230 190 130), 1); $cos.DashStyle = 'Dash'; $g.DrawLine($cos, 14, 283, 156, 283); $g.DrawLine($cos, 14, 302, 156, 302); $cos.Dispose()
                    for ($i = 0; $i -lt 6; $i++) {
                        $bx = 20 + $i * 23
                        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 82 42 18))), $bx - 2, 285, 16, 17)
                        if ($i -lt $script:balas) {
                            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 226 182 74))), $bx, 278, 12, 22)
                            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 196 110 62))), $bx, 272, 12, 12)
                            $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 120 255 246 200))), ($bx + 2), 280, 3, 18)
                        }
                    }
                    Texto-Color $g "DUELOS  $($script:duelosG) - $($script:duelosP)" 'EdmundMcMillen_INTLv4' 15 172 283 (C 255 214 120) (C 30 14 6) 4
                    Texto-Color $g "DISPAROS: $($script:disparos)" 'EdmundMcMillen_INTLv4' 13 300 285 (C 250 236 205) (C 30 14 6) 3
                }
            }
            Pintar-Burbuja $g $k
            Pintar-Flotantes $g
        }
        default {
            $scan = New-Object System.Drawing.Pen((C 28 0 0), 1)
            for ($y = 54; $y -lt $H; $y += 4) { $g.DrawLine($scan, 2, $y, $W - 2, $y) }
            $scan.Dispose()
            $g.DrawString($k.Titulo, (FntP($k.FuenteTitulo, 20, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush($k.Sombra)), 15, 10)
            $pen2 = New-Object System.Drawing.Pen($k.Borde, 2)
            $g.DrawLine($pen2, 0, 52, $W, 52); $pen2.Dispose()
        }
    }
    if ($script:glitching) {
        for ($i = 0; $i -lt 6; $i++) {
            $col = @((C 255 0 0), (C 255 255 255), (C 0 255 255), (C 80 0 0))[$Rnd.Next(4)]
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($col)), $Rnd.Next(-50, $W), $Rnd.Next(0, $H), $Rnd.Next(40, 300), $Rnd.Next(1, 7))
        }
    }
    $ancho = if ($k.Estilo -in @('tele', 'mew', 'oeste', 'culto', 'kaiju', 'femta')) { 4 } elseif ($k.Estilo -eq 'lobo') { 2 } else { 3 }
    $pen = New-Object System.Drawing.Pen($k.Borde, $ancho)
    $g.DrawRectangle($pen, 1, 1, $W - 3, $H - 3); $pen.Dispose()
})

$script:drag = $false
# ¿hay un personaje dibujado bajo el ratón?
function Actor-En-Raton {
    if ($script:actores.Count -eq 0) { return $null }
    $pt = $form.PointToClient([System.Windows.Forms.Cursor]::Position); $x = $pt.X / $script:K; $y = $pt.Y / $script:K
    foreach ($a in @($script:actores.Values)) { $r = $a.Rect; if ($a.Visible -and $x -ge $r[0] -and $x -le ($r[0] + $r[2]) -and $y -ge $r[1] -and $y -le ($r[1] + $r[3])) { return $a.Id } }
    return $null
}
function Clic-Actor($id) {
    if (Ocupado) { return }
    switch ($script:skin.Estilo) {
        'culto' { if ($id -eq 'L') { Cordero-Clic } else { Cabra-Clic } }
        'kaiju' { Kaiju-Ataque $id }
        'zorro' { Averi-Clic }
        'mew' { Golpe-Guillotina }
        'oeste' { Zodiac-Clic }
        'pressure' { Sebastian-Clic }
        'dod' { Pursuer-Clic }
        'teto' { Teto-Clic }
        'enfosi' { Enfosi-Clic $id }
        'femta' { Token-Clic }
        'pop' { Tetra-Clic }
        'pizza' { Kevin-Clic }
        'punk' { Ky-Clic }
        'gran' { Gran-Clic }
        'abismo' { if ($id -eq 'M') { Nn-Mitty } else { Nn-Clic } }
        'evil' { Es-Clic }
        'niebla' { if ($id -eq 'G') { Sf-Gato } else { Sf-Clic } }
    }
}
$mDown = {
    # Kevin: tocar su pizza (mala idea)
    if ($script:skin.Estilo -eq 'pizza' -and $_.Button -eq 'Left' -and (Pizza-En-Raton)) { Pizza-Tocar; return }
    # Kennyoung: botón de suscribirse del reproductor
    if ($script:skin.Estilo -eq 'punk' -and $_.Button -eq 'Left' -and (Sub-En-Raton)) { Ky-Suscribir; return }
    $id = Actor-En-Raton
    if ($id) { if ($_.Button -eq 'Right') { Iniciar-Discusion } else { Clic-Actor $id }; return }
    $script:drag = $true; $script:p0 = [System.Windows.Forms.Cursor]::Position; $script:f0 = $form.Location
    # Zodiac dispara a todo lo que se mueve... incluida la ventana
    if ($script:skin.Estilo -eq 'oeste' -and -not (Ocupado)) { Zodiac-Mover }
    if ($script:skin.Estilo -eq 'teto' -and -not (Ocupado) -and ([Environment]::TickCount - $script:tetoArrastre) -gt 8000) {
        $script:tetoArrastre = [Environment]::TickCount; Sonido 'wheee'; $script:tetoVozT = $script:tetoArrastre
        Decir (Azar @('¡Wheee~! ¡Me llevas de paseo!', '¡Wheee! ¡Más rápido! ...no, más despacio, que me mareo.', '¡Wheee~! ¡Como en el metro, pero sin metro!'))
    }
}
$mMove = {
    if ($script:actores.Count -gt 0 -and -not $script:drag) { $form.Cursor = $(if ((Actor-En-Raton) -or ($script:skin.Estilo -eq 'pizza' -and (Pizza-En-Raton)) -or ($script:skin.Estilo -eq 'punk' -and (Sub-En-Raton))) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }) }
    if ($script:drag -and -not $script:glitching) {
        $p = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(($script:f0.X + $p.X - $script:p0.X), ($script:f0.Y + $p.Y - $script:p0.Y))
        if ($script:inv) { Colocar-Invitado }   # el invitado viaja pegado al panel
    }
}
$mUp = { $script:drag = $false }
$form.Add_MouseDown($mDown); $form.Add_MouseMove($mMove); $form.Add_MouseUp($mUp)

function Cargar-Img($rel) {
    if (-not $rel) { return $null }
    $ruta = Ruta $rel
    if (Test-Path $ruta) { return [System.Drawing.Image]::FromFile($ruta) }
    return $null
}

function Construir-UI {
    $k = $Skins[$script:skinNombre]; $script:skin = $k
    # quitar las imágenes de la ventana antes de liberarlas (evita la ventana de error al cambiar de skin)
    $caraTimer.Stop(); $tvTimer.Stop(); $revTimer.Stop()
    Fin-Discusion $true
    if ($script:pb) { $script:pb.Image = $null; $form.Controls.Remove($script:pb); $script:pb.Dispose(); $script:pb = $null }
    foreach ($im in @($script:imgs.Values)) { if ($im) { $im.Dispose() } }
    foreach ($set in @($script:caras.Values)) { foreach ($im in $set) { if ($im) { $im.Dispose() } } }
    $script:imgs = @{}; $script:caras = @{}
    if ($script:tvRuido) { $script:tvRuido.Dispose(); $script:tvRuido = $null }
    $script:urlLbl = $null
    $script:gHP = 400; $script:gMax = 400; $script:gFase2 = $false; $script:gVivo = $true
    $snTimer.Stop(); $fxTimer.Stop(); $humoTimer.Stop(); $script:snApuntando = $false; $script:hits.Clear(); $script:flash = 0
    $script:balas = 6
    $script:telarana = $null; $telTimer.Stop(); $script:hambre = 0; $script:salto = 0
    $script:gComidos = 0; $script:disparos = 0; $script:agujeros2.Clear(); $script:fogonazo = 0
    $script:modoTienda = $false; $script:toques = 0; $script:enfadoFx = 0; $script:destello = 0
    $script:acechando = $false; $acechoTimer.Stop(); $script:zarpas.Clear(); $script:ondas.Clear(); $script:gotas.Clear(); $script:rojoFx = 0
    $script:pajaros.Clear(); $script:birdbrains = 0; $script:duelo = $null; $script:tkCd = 1
    # personajes dibujados y estado de las skins nuevas
    $actTimer.Stop(); $kRevTimer.Stop()
    if ($k.Estilo -ne 'gran') { Gran-Musica-Off }
    Quitar-Actores
    if ($script:bmpEscena) { $script:bmpEscena.Dispose(); $script:bmpEscena = $null }
    $script:fe = 60; $script:seguidores = 0; $script:ritualFx = 0
    Kaiju-Reiniciar
    $script:antojo = 0
    $script:pzFx = 0; $script:pzQueso = $false; $script:pzEnfado = 0.0; $script:pzGrito = $null; $script:pzLluvia.Clear()
    $script:kyFx = 0; $script:kyConc = 0; $script:kyFlash = 0; $script:kyAmp = 0.0; $script:kyVideo = $null
    if ($script:pzReparto -gt 0) { $script:pzReparto = 0; $script:pzTrozos = 8 }
    $form.Controls.Clear()

    $T = if ($k.Top) { $k.Top } else { 0 }
    $conActores = [bool]$k.Actores
    $conGif = [bool]$k.Gif -and -not $conActores
    $W = if ($k.Ancho) { $k.Ancho } elseif ($conGif) { 616 } else { 408 }
    $form.Size = New-Object System.Drawing.Size($W, $k.Alto)
    $form.BackColor = $k.Fondo
    $form.Opacity = (Opacidad-Base)
    $form.Text = $script:skinNombre

    $xTit = if ($k.TituloX) { $k.TituloX } elseif ($k.Estilo -eq 'web') { 48 } else { 12 }   # TituloX: deja sitio a un logo a la izquierda
    $estiloTit = if ($k.FuenteTitulo -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
    $titulo = New-Object System.Windows.Forms.Label
    $titulo.Text = $k.Titulo
    $titulo.Font = Fnt($k.FuenteTitulo, 20, $estiloTit)
    $titulo.ForeColor = $k.TituloColor
    $titulo.BackColor = [System.Drawing.Color]::Transparent
    $titulo.UseMnemonic = $false   # para que se vea el "&" de CORDERO & CABRA
    $titulo.AutoSize = $true
    $titulo.Location = New-Object System.Drawing.Point($xTit, 6)
    # las fuentes de Mewgenics solo se ven con el dibujado de GDI+
    $privada = [bool](@($k.FuenteTitulo, $k.Fuente, $k.BurFuente) | Where-Object { $_ -and $script:fuentesPriv.ContainsKey($_) })

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = $k.Sub
    $sub.Font = Fnt($(if ($k.Fuente -eq 'Impact') { 'Segoe UI' } else { $k.Fuente }), 8, [System.Drawing.FontStyle]::Bold)
    $sub.ForeColor = $k.SubColor
    $sub.BackColor = [System.Drawing.Color]::Transparent
    $sub.AutoSize = $true
    if ($privada) { $titulo.UseCompatibleTextRendering = $true; $sub.UseCompatibleTextRendering = $true }
    $form.Controls.AddRange(@($titulo, $sub))
    $xSub = if ($k.TituloImg) { 166 } else { $xTit + [int]($titulo.PreferredWidth / $script:K) + 2 }
    $sub.Location = New-Object System.Drawing.Point($xSub, 26)
    foreach ($c in @($titulo, $sub)) { $c.Add_MouseDown($mDown); $c.Add_MouseMove($mMove); $c.Add_MouseUp($mUp) }

    $script:bi = 0
    $bCerrar = Nuevo-Boton 'X' ($W - 40) 12 28 28; $bCerrar.ForeColor = $k.BarraBtnTexto
    $bCerrar.Add_Click({ $form.Close() })
    $txtMin = if ($k.Fuente -eq 'Impact') { '–' } else { '_' }
    $bMin = Nuevo-Boton $txtMin ($W - 74) 12 28 28; $bMin.ForeColor = $k.BarraBtnTexto
    $bMin.Add_Click({ $form.WindowState = 'Minimized' })
    $bSkins = Nuevo-Boton 'Skins' ($W - 150) 12 70 28; $bSkins.ForeColor = $k.BarraBtnTexto
    # el menú Skins se abre en el grupo de la skin que llevas puesta
    $bSkins.Add_Click({ if (-not (Ocupado)) { $script:modoSkins = -not $script:modoSkins; if ($script:modoSkins) { $script:pagSkins = Pagina-De-Skin $script:skinNombre }; Mostrar-Pagina } })
    $bAjustes = Nuevo-Boton 'Ajustes' ($W - 226) 12 72 28; $bAjustes.ForeColor = $k.BarraBtnTexto
    $bAjustes.Add_Click({ Mostrar-Ajustes })
    $form.Controls.Add($bAjustes)
    if ($k.Estilo -in @('hacker', 'lobo', 'mlg', 'gunsaw')) { Hover-Color $bAjustes }

    $script:grid = New-Object System.Windows.Forms.Panel
    $grid.Location = New-Object System.Drawing.Point(16, (66 + $T))
    $grid.Size = New-Object System.Drawing.Size(376, 168)
    $grid.BackColor = [System.Drawing.Color]::Transparent

    $script:lblPag = New-Object System.Windows.Forms.Label
    $lblPag.ForeColor = $k.StatusColor
    $lblPag.BackColor = [System.Drawing.Color]::Transparent
    $lblPag.Font = Fnt($(if ($k.Fuente -eq 'Impact') { 'Impact' } else { $k.Fuente }), 10, $(if ($k.Fuente -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }))
    $lblPag.TextAlign = 'MiddleCenter'
    $lblPag.Location = New-Object System.Drawing.Point(140, (242 + $T))
    $lblPag.Size = New-Object System.Drawing.Size(128, 28)
    if ($privada) { $lblPag.UseCompatibleTextRendering = $true }

    $bAnt = Nuevo-Boton '<' 16 (242 + $T) 120 28
    # < y > pasan de página; en el menú Skins pasan de grupo (y dan la vuelta)
    $bAnt.Add_Click({
        if ($script:modoSkins) { $n = (Paginas-Skins).Count; $script:pagSkins = ($script:pagSkins - 1 + $n) % $n; Mostrar-Pagina }
        elseif ($script:pagina -gt 0) { $script:pagina--; Mostrar-Pagina }
    })
    $bSig = Nuevo-Boton '>' 272 (242 + $T) 120 28
    $bSig.Add_Click({
        if ($script:modoSkins) { $n = (Paginas-Skins).Count; $script:pagSkins = ($script:pagSkins + 1) % $n; Mostrar-Pagina }
        elseif ($script:pagina -lt $totalPaginas - 1) { $script:pagina++; Mostrar-Pagina }
    })

    $script:status = New-Object System.Windows.Forms.Label
    $status.ForeColor = $k.StatusColor
    $form.Controls.AddRange(@($bSkins, $bMin, $bCerrar, $grid, $bAnt, $lblPag, $bSig, $status))
    if ($k.Estilo -in @('hacker', 'lobo', 'mlg', 'gunsaw')) { foreach ($b in @($bSkins, $bMin, $bCerrar, $bAnt, $bSig)) { Hover-Color $b } }

    if ($k.Estilo -eq 'web') {
        $candado = New-Object System.Windows.Forms.Label
        $candado.Text = '🔒'
        $candado.Font = Fnt('Segoe UI Symbol', 9)
        $candado.ForeColor = (C 30 140 60)
        $candado.BackColor = [System.Drawing.Color]::White
        $candado.Location = New-Object System.Drawing.Point(100, 63)
        $candado.Size = New-Object System.Drawing.Size(20, 19)
        $script:urlLbl = New-Object System.Windows.Forms.Label
        $urlLbl.Text = $k.Url
        $urlLbl.Font = Fnt('Segoe UI', 9)
        $urlLbl.ForeColor = (C 40 40 40)
        $urlLbl.BackColor = [System.Drawing.Color]::White
        $urlLbl.Location = New-Object System.Drawing.Point(121, 64)
        $urlLbl.Size = New-Object System.Drawing.Size(($W - 142), 18)
        $form.Controls.AddRange(@($candado, $urlLbl))
    }

    if ($conActores) {
        # personajes grandes dibujados en el panel y bocadillo transparente encima del dibujo
        foreach ($def in $k.Actores) { Nuevo-Actor $def }
        if ($k.Estilo -eq 'enfosi') { Enfosi-Reset } else { $script:ef = $null }
        if ($k.Estilo -eq 'gran') { Gran-Reset } else { $script:gr = $null }
        # Nanachi: se guarda lo que lleva (estofados, mullido); al irse se liberan sus caras y la olla
        if ($k.Estilo -eq 'abismo') { Nn-Reset } else { Nn-Liberar; if ($script:nnOlla) { $script:nnOlla.Dispose(); $script:nnOlla = $null } }
        # Evil Scary: guarda su distancia y sus contadores; al irse se borra todo y se suelta la cara del susto
        if ($k.Estilo -eq 'evil') { Es-Reset } else { $script:es = $null; if ($script:esSusto) { $script:esSusto.Dispose(); $script:esSusto = $null } }
        # Soft Fuzzy Man: guarda su existencia y sus contadores mientras sea la skin activa
        if ($k.Estilo -eq 'niebla') { Sf-Reset } else { $script:sf = $null }
        $status.BackColor = [System.Drawing.Color]::Transparent
        $status.ForeColor = $k.BurTexto
        $status.UseMnemonic = $false
        if ($privada) { $status.UseCompatibleTextRendering = $true }
        $tamBur = if ($k.BurFuente -eq 'Segoe Print') { 8 } elseif ($k.BurFuente -eq 'TikaFont Adjusted') { 9.5 } else { 9 }
        $status.Font = Fnt($k.BurFuente, $tamBur, [System.Drawing.FontStyle]::Bold)
        $status.Location = New-Object System.Drawing.Point($k.Burbuja[0], $k.Burbuja[1])
        $status.Size = New-Object System.Drawing.Size($k.Burbuja[2], $k.Burbuja[3])
        $status.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
        $script:ultimoTick = [Environment]::TickCount; $actTimer.Start()
    }
    if ($conGif) {
        $script:imgs = @{ main = (Cargar-Img $k.Gif); clic = (Cargar-Img $k.GifClic); raro = (Cargar-Img $k.GifRaro); fase2 = (Cargar-Img $k.GifFase2); titulo = (Cargar-Img $k.TituloImg) }
        if ($k.Extra) { foreach ($e in $k.Extra.Keys) { $script:imgs[$e] = Cargar-Img $k.Extra[$e] } }
        if ($k.Caras) { foreach ($c in $k.Caras.Keys) { $script:caras[$c] = @((Cargar-Img $k.Caras[$c][0]), (Cargar-Img $k.Caras[$c][1])) } }
        $script:pb = New-Object System.Windows.Forms.PictureBox
        $pb.SizeMode = 'Zoom'
        $pb.Cursor = 'Hand'
        $pb.Image = if ($script:caras.Count -gt 0) { $script:caras.cerrados[0] } else { $script:imgs.main }
        $pb.Location = New-Object System.Drawing.Point($k.Pb[0], $k.Pb[1])
        $pb.Size = New-Object System.Drawing.Size($k.Pb[2], $k.Pb[3])
        $pb.BackColor = if ($k.PbFondo) { $k.PbFondo } else { [System.Drawing.Color]::Transparent }
        if ($k.PbBorde) { $pb.BorderStyle = 'FixedSingle' }
        # clic derecho sobre el personaje: empieza una discusión
        $pb.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
        $pb.Add_Click({
            if ($_.Button -eq 'Right') { return }
            $k = $script:skin
            switch ($k.Estilo) {
                'tele' { Cara 'clic' 3000; Decir (Azar $k.Clic) }
                'mew' { Golpe-Guillotina }
                'culto' { Cordero-Clic }
                'kaiju' { Kaiju-Ataque 'P' }
                'zorro' { Averi-Clic }
                'mlg' { }   # Mikaela dispara al soltar el ratón (Snipe)
                'gunsaw' {
                    if ($k.Telarana) {
                        $presa = Velvet-Escupir
                        if ($presa) { Decir "$(Azar $k.Clic) ($presa ha quedado atrapado)" }
                    } elseif ($k.Hambre) { Dune-Comer }
                }
                'oeste' {
                    if ($script:balas -lt 6) {
                        $script:balas = 6; Cara 'recarga' 1500; Sonido 'loco'
                        Decir '*Recarga el revólver.* Seis balas. Que empiece el baile.'
                        $form.Invalidate()
                    } else { Cara 'pose' 3000; Decir (Azar $k.Clic) }
                }
                default { Decir (Azar $k.Clic) 'abiertos' }
            }
        })
        if ($k.Estilo -eq 'mlg') {
            # Snipe: mantener pulsado para cargar, soltar para disparar
            $pb.Cursor = 'Cross'
            $pb.Add_MouseDown({ if ($_.Button -eq 'Left') { $script:snPos = $_.Location; Snipe-Inicio } })
            $pb.Add_MouseMove({ $script:snPos = $_.Location; if ($script:snApuntando) { $this.Invalidate() } })
            $pb.Add_MouseUp({ if ($_.Button -eq 'Left') { $script:snPos = $_.Location; Snipe-Disparo } })
            $pb.Add_Paint({
                $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'
                if ($script:snApuntando) {
                    $x = $script:snPos.X; $y = $script:snPos.Y
                    $rojo = New-Object System.Drawing.Pen([System.Drawing.Color]::Red, 2)
                    $g.DrawEllipse($rojo, ($x - 22), ($y - 22), 44, 44)
                    $g.DrawLine($rojo, ($x - 30), $y, ($x - 8), $y); $g.DrawLine($rojo, ($x + 8), $y, ($x + 30), $y)
                    $g.DrawLine($rojo, $x, ($y - 30), $x, ($y - 8)); $g.DrawLine($rojo, $x, ($y + 8), $x, ($y + 30))
                    $g.FillEllipse([System.Drawing.Brushes]::Red, ($x - 3), ($y - 3), 6, 6)
                    $rojo.Dispose()
                }
                foreach ($h in $script:hits) {
                    Dibujar-Hit $g $h.X $h.Y (12 * $script:K)
                    $g.DrawString('+100', (Fnt('Arial Black', 9)), [System.Drawing.Brushes]::Lime, ($h.X + 12), ($h.Y - 24 + $h.T))
                }
                if ($script:flash -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($script:flash * 50, 255, 255, 255))), 0, 0, $this.Width, $this.Height) }
            })
        }
        if ($k.Estilo -eq 'tele') { $script:tvRuido = Nuevo-Ruido 64 48 }

        $status.BackColor = $k.BurFondo
        $status.ForeColor = $k.BurTexto
        $status.BorderStyle = 'FixedSingle'
        $status.Padding = New-Object System.Windows.Forms.Padding(4)
        $tamBur = if ($k.BurFuente -eq 'Segoe Print') { 8 } else { 9 }
        $status.Font = Fnt($k.BurFuente, $tamBur, [System.Drawing.FontStyle]::Bold)
        $status.Location = New-Object System.Drawing.Point($k.Burbuja[0], $k.Burbuja[1])
        $status.Size = New-Object System.Drawing.Size($k.Burbuja[2], $k.Burbuja[3])
        $form.Controls.Add($pb)
    } elseif (-not $conActores) {
        $status.BackColor = [System.Drawing.Color]::Black
        $status.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
        $status.Font = Fnt('Consolas', 8.5)
        $status.Location = New-Object System.Drawing.Point(14, 278)
        $status.Size = New-Object System.Drawing.Size(380, 22)
    }

    Montar-Caja-Texto
    # todo se diseña a tamaño base y luego se escala de una vez (evita textos cortados)
    $loc = $form.Location
    Escalar $form
    $form.Location = $loc
    Mostrar-Pagina
    $script:twTexto = ''; $script:twPos = 0; $status.Text = ''; $script:twBloqueo = 0
    $form.Invalidate()
}

Construir-UI
# recordar dónde estaba la ventana
if ($script:aj.Posicion -and $script:aj.X -ne '' -and $script:aj.Y -ne '') {
    $pt = New-Object System.Drawing.Point([int]$script:aj.X, [int]$script:aj.Y)
    if ([System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.WorkingArea.Contains($pt) }) { $form.StartPosition = 'Manual'; $form.Location = $pt }
}
$form.Add_FormClosing({ if ($form.WindowState -eq 'Normal') { $script:aj.X = $form.Left; $script:aj.Y = $form.Top }; Guardar-Ajustes })
# ================= AVISO DE EPILEPSIA (sale cada vez que se abre el panel) =================
# Fondo negro con la imagen skins\logo\aviso.jpg muy oscurecida, el aviso en letras grandes y dos botones.
# Mientras está, el panel cuenta como "ocupado" (no habla ni cambia de skin). Al cerrarlo sigue el arranque normal.
$script:avisoOv = $null; $script:avisoImg = $null
function Mostrar-Aviso {
    $script:transicion = $true
    $script:avisoImg = Cargar-Img 'skins\logo\aviso.jpg'
    $ov = New-Object System.Windows.Forms.Panel
    $ov.Location = New-Object System.Drawing.Point(0, 0); $ov.Size = $form.ClientSize; $ov.BackColor = [System.Drawing.Color]::Black
    Doble-Buffer $ov
    $ov.Add_Paint({ $_.Graphics.ScaleTransform($script:K, $script:K); Pintar-Aviso $_.Graphics ([int]($this.Width / $script:K)) ([int]($this.Height / $script:K)) })
    $W = [int]($ov.Width / $script:K); $H = [int]($ov.Height / $script:K)
    # botones: activar el modo seguro (o ya activado) y continuar
    $b1 = New-Object System.Windows.Forms.Button; $b2 = New-Object System.Windows.Forms.Button
    foreach ($b in @($b1, $b2)) {
        $b.FlatStyle = 'Flat'; $b.Font = Fnt('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold); $b.Cursor = 'Hand'
        $b.FlatAppearance.BorderSize = [Math]::Max(1, [int](2 * $script:K)); $b.Size = New-Object System.Drawing.Size([int](210 * $script:K), [int](34 * $script:K))
    }
    $b1.Location = New-Object System.Drawing.Point([int](($W / 2 - 220) * $script:K), [int](($H - 52) * $script:K))
    $b2.Location = New-Object System.Drawing.Point([int](($W / 2 + 10) * $script:K), [int](($H - 52) * $script:K))
    Aviso-Botones $b1 $b2
    $b1.Add_Click({ $script:aj.Epilepsia = -not $script:aj.Epilepsia; Guardar-Ajustes; Aviso-Botones $this $script:avisoB2; $script:avisoOv.Invalidate() })
    $b2.Add_Click({ Cerrar-Aviso })
    $script:avisoB2 = $b2
    $ov.Controls.AddRange(@($b1, $b2))
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:avisoOv = $ov
}
function Aviso-Botones($b1, $b2) {
    if ($script:aj.Epilepsia) {
        $b1.Text = '✔  MODO SEGURO: SÍ'; $b1.BackColor = (C 40 140 70); $b1.ForeColor = [System.Drawing.Color]::White; $b1.FlatAppearance.BorderColor = (C 140 230 160)
    } else {
        $b1.Text = 'ACTIVAR MODO SEGURO'; $b1.BackColor = (C 255 210 40); $b1.ForeColor = [System.Drawing.Color]::Black; $b1.FlatAppearance.BorderColor = [System.Drawing.Color]::White
    }
    $b2.Text = 'CONTINUAR  ▶'; $b2.BackColor = (C 24 24 28); $b2.ForeColor = [System.Drawing.Color]::White; $b2.FlatAppearance.BorderColor = [System.Drawing.Color]::White
}
function Pintar-Aviso($g, $W, $H) {
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Black)
    # la imagen de fondo, muy oscura para que se lea bien el texto
    if ($script:avisoImg) { [void](Dibujar-Cubriendo $g $script:avisoImg $W $H 1.0 0.5 0.4) }
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 200 0 0 0))), 0, 0, $W, $H)
    # franjas amarillas y negras de peligro arriba y abajo
    foreach ($y in @(0, ($H - 8))) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 210 40))), 0, $y, $W, 8)
        for ($x = -10; $x -lt $W; $x += 22) { $g.FillPolygon([System.Drawing.Brushes]::Black, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF($x, ($y + 8))), (New-Object System.Drawing.PointF(($x + 8), $y)), (New-Object System.Drawing.PointF(($x + 16), $y)), (New-Object System.Drawing.PointF(($x + 8), ($y + 8))))) }
    }
    # ⚠ ALERTA en grande
    $t1 = '⚠  ALERTA  ⚠'; $f1 = FntP('Segoe UI Symbol', 30, [System.Drawing.FontStyle]::Bold)
    $w1 = $g.MeasureString($t1, $f1).Width
    $g.DrawString($t1, $f1, (New-Object System.Drawing.SolidBrush((C 255 210 40))), [float]($W / 2 - $w1 / 2), 18)
    $t2 = 'EPILEPSIA FOTOSENSIBLE'; $f2 = FntP('Arial Black', 15)
    $w2 = $g.MeasureString($t2, $f2).Width
    $g.DrawString($t2, $f2, [System.Drawing.Brushes]::White, [float]($W / 2 - $w2 / 2), 72)
    # el mensaje
    $msg = "Este programa tiene luces que parpadean, destellos de colores y pantallas que tiemblan. Su creador NO puede controlarlos.`n`nSi tienes epilepsia o te molestan las luces, activa el MODO SEGURO."
    $fm = New-Object System.Drawing.StringFormat; $fm.Alignment = 'Center'
    $g.DrawString($msg, (FntP('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 236 236 236))), (New-Object System.Drawing.RectangleF(30, 106, ($W - 60), ($H - 176))), $fm)
    $g.DrawString('Puedes cambiarlo cuando quieras en Ajustes.', (FntP('Segoe UI', 8.5, [System.Drawing.FontStyle]::Italic)), (New-Object System.Drawing.SolidBrush((C 170 170 170))), (New-Object System.Drawing.RectangleF(30, ($H - 76), ($W - 60), 18)), $fm)
}
function Cerrar-Aviso {
    if ($script:avisoOv) { $form.Controls.Remove($script:avisoOv); $script:avisoOv.Dispose(); $script:avisoOv = $null }
    if ($script:avisoImg) { $script:avisoImg.Dispose(); $script:avisoImg = $null }
    $script:transicion = $false
    Arranque
}
# lo que pasa al abrir el panel, después del aviso
function Arranque {
    # primero el logo de JOSEPABLINI CORPORATION y luego la intro de la skin (en modo seguro, sin intros)
    if ($script:aj.Intros -and -not $script:aj.Epilepsia) { Logo-Inicio } else { Efecto-Entrada $null }
    # la primera vez que se abre el panel sale la guía del panda
    if (-not $script:aj.Guia) { $script:guiaCalma = 0; $guiaInicio.Start() }
}

$form.Add_Shown({
    $twTimer.Start(); $idleTimer.Start(); $ambTimer.Start(); $hambreTimer.Start()
    Aplicar-Ajustes
    # siempre sale antes el aviso de epilepsia; al cerrarlo, Arranque sigue con el logo y la intro
    Mostrar-Aviso
})
[void]$form.ShowDialog()
