# c00lgui v3 - panel lanzador con skins de asistentes
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
# Nombre = texto del botón | Abrir = programa, archivo o URL | Web = (opcional) URL si el programa no está instalado
$Botones = @(
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

# ================= SKINS =================
function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

$Skins = [ordered]@{
    # ================================================================ c00lgui
    'c00lgui' = @{
        Estilo = 'hacker'; Titulo = 'c00lgui'; Sub = 'v3'; Alto = 312
        Fondo = (C 0 0 0); Borde = (C 255 0 0); Sombra = (C 90 0 0)
        TituloColor = (C 255 0 0); SubColor = (C 140 0 0)
        BtnFondo = (C 0 0 0); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 40 40); BtnBorde = (C 255 0 0); BtnBordeAncho = 1
        BtnHover = (C 45 0 0); BtnPress = (C 255 0 0); BarraBtnTexto = (C 255 0 0)
        StatusColor = (C 255 0 0); Fuente = 'Arial'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 2
        Hola = @(
            '> c00lgui v3 loaded. welcome back.'
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
        FondoImg = 'skins\guillotina\callejon.jpg'; IntroImg = 'skins\guillotina\cementerio.jpg'
        Actores = @(
            @{ Id = 'G'; Gif = 'skins\guillotina\g_idle.gif'; Rect = @(432, 66, 316, 190)
               Extra = @{ furiosa = 'skins\guillotina\g_furiosa.gif'; clic = 'skins\guillotina\g_enfado.gif'; inhala = 'skins\guillotina\g_inhala.gif'; inhalaf = 'skins\guillotina\g_inhala_f.gif'
                          lanza = 'skins\guillotina\g_lanza.gif'; barriga = 'skins\guillotina\g_barriga.gif'; digiere = 'skins\guillotina\g_digiere.gif'; herida = 'skins\guillotina\g_herida.gif' } }
        )
        Cartel = 'skins\guillotina\cartel_g.png'
        Sonidos = @{
            intro = @('skins\guillotina\s_enfado_sfx.wav'); furia = @('skins\guillotina\s_enfado.wav'); radio = @('skins\guillotina\radio.wav')
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
            'Kasane Teto'          = @('*Guillotina mira las coletas de Teto. Parecen dos panes. Se relame.*', '*Teto le ofrece pan a Guillotina. Guillotina se come el pan. Y la bolsa. Y casi a Teto.*')
            'Token'                = @('*Guillotina intentó comerse a Token. Token siguió poniendo breakcore dentro.*', '*A Guillotina le gusta el bajo de Token. Le hace cosquillas en la barriga.*')
            'Tetra'                = @('*Guillotina se comió los fideos de Tetra. Y el vaso. Tetra ni se inmutó.*', '*Mira los pendientes de pez de Tetra. Se relame.*')
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
        Clic = @('¡Eh! Me has hecho cosquillas en la oreja.', '¡Hola! Sí, sigo aquí. Siempre.', '*Mueve la cola tan fuerte que se cae.*', '¡Te quiero! ...¡como amiga! ¡Como asistente amiga!')
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
            '¡Hoppy Hopscotch es mi mejor amigo para siempre!'
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
            @{ Id = 'T'; Gif = 'skins\teto\teto.png'; Rect = @(566, 30, 150, 266); Baila = $true }
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
        BtnFondo = (C 14 8 10); BtnTexto = (C 255 255 255); BtnTextoHover = (C 255 255 255); BtnBorde = (C 230 20 40); BtnBordeAncho = 2
        BtnHover = (C 230 20 40); BtnPress = (C 255 255 255); BarraBtnTexto = (C 255 255 255)
        StatusColor = (C 255 255 255); Fuente = 'Consolas'; FuenteTitulo = 'Arial Black'; Opacidad = 1.0; Velocidad = 1
        Ancho = 760; Mezclar = $true; Gif = 'skins\token\token.png'; Logo = 'skins\token\logo.png'
        # dibujo de Token: fanart de kengop1 (DeviantArt); cabeza de la intro: TheDalmatianCatHybri
        Actores = @(
            @{ Id = 'K'; Gif = 'skins\token\token.png'; Rect = @(548, 60, 144, 212); Respira = $true }
        )
        Sonidos = @{
            moneda = @('skins\token\moneda.wav'); golpe = @('skins\token\golpe.wav'); breakcore = @('skins\token\breakcore.wav'); glitch = @('skins\token\glitch.wav')
        }
        Burbuja = @(424, 278, 322, 34); BurFondo = $null; InvFondo = (C 14 8 10); BurTexto = (C 255 255 255); BurFuente = 'Consolas'
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
}

$script:skinNombre = 'c00lgui'
if (Test-Path $ArchivoSkin) { $s = (Get-Content $ArchivoSkin -Raw).Trim(); if ($Skins.Contains($s)) { $script:skinNombre = $s } }

$PorPagina = 12
$script:pagina = 0
$script:modoSkins = $false
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
$totalPaginas = [Math]::Max(1, [Math]::Ceiling($Botones.Count / $PorPagina))

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
            # femtanyl: negro, rojo y blanco, estática y una pantalla de recreativa
            $g.Clear((C 8 4 6))
            $rn = New-Object System.Random 13
            for ($i = 0; $i -lt 40; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $rn.Next(20, 70) 200 20 30))), 0, $rn.Next(52, [int]$H), $W, $rn.Next(1, 4)) }
            for ($i = 0; $i -lt 900; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB $rn.Next(20, 90) 255 255 255))), $rn.Next(0, [int]$W), $rn.Next(52, [int]$H), 1, 1) }
            $st = $g.Save(); $g.TranslateTransform(30, 300); $g.RotateTransform(-6)
            Texto-Color $g 'femtanyl' 'Arial Black' 96 0 (-110) (ARGB 26 255 30 40) (ARGB 0 0 0 0) 1
            $g.Restore($st)
            # pantalla de la recreativa con rayos rojos detrás de Token
            $g.SetClip((New-Object System.Drawing.RectangleF(412, 62, [float]($W - 422), 210)))
            $cx = 620; $cy = 150; $br = New-Object System.Drawing.SolidBrush((ARGB 55 230 20 40))
            for ($i = 0; $i -lt 16; $i++) {
                $a1 = [Math]::PI / 180 * ($i * 22.5 - 5); $a2 = [Math]::PI / 180 * ($i * 22.5 + 5)
                $g.FillPolygon($br, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$cx, [float]$cy)), (New-Object System.Drawing.PointF([float]($cx + 500 * [Math]::Cos($a1)), [float]($cy + 500 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF([float]($cx + 500 * [Math]::Cos($a2)), [float]($cy + 500 * [Math]::Sin($a2))))))
            }
            $br.Dispose()
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse(($cx - 120), ($cy - 120), 240, 240)
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pg.CenterColor = (ARGB 120 230 20 40); $pg.SurroundColors = [System.Drawing.Color[]]@((ARGB 0 230 20 40))
            $g.FillPath($pg, $gp); $pg.Dispose(); $gp.Dispose()
            $g.ResetClip()
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 230 20 40), 3)), 412, 62, ($W - 422), 210)
            $g.DrawRectangle((New-Object System.Drawing.Pen((ARGB 90 255 255 255), 1)), 416, 66, ($W - 430), 202)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((ARGB 120 230 20 40))), 556, 262, 130, 12)
            # barra de arriba negra con línea roja
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 0 0 0))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), 0, 49, $W, 3)
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
            # caja negra con borde rojo y esquinas cortadas
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]($x + 8), [float]$y)), (New-Object System.Drawing.PointF([float]($x + $w), [float]$y)), (New-Object System.Drawing.PointF([float]($x + $w), [float]($y + $h - 8))), (New-Object System.Drawing.PointF([float]($x + $w - 8), [float]($y + $h))), (New-Object System.Drawing.PointF([float]$x, [float]($y + $h))), (New-Object System.Drawing.PointF([float]$x, [float]($y + 8))))
            $g.FillPolygon((New-Object System.Drawing.SolidBrush((ARGB 235 10 4 6))), $pts)
            $g.DrawPolygon((New-Object System.Drawing.Pen((C 230 20 40), 2)), $pts)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 20 40))), [float]($x + $w - 40), [float]($y - 3), 30, 4)
        }
        'pop' {
            # bocadillo morado translúcido con borde de neón rosa y cian
            $r = Ruta-Redonda $x $y $w $h 12
            $g.FillPath((New-Object System.Drawing.SolidBrush((ARGB 215 34 14 64))), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((ARGB 90 255 92 190), 5)), $r)
            $g.DrawPath((New-Object System.Drawing.Pen((C 90 230 250), 1.6)), $r); $r.Dispose()
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
$script:twTexto = ''; $script:twPos = 0; $script:twTick = 0
$twTimer = New-Object System.Windows.Forms.Timer
$twTimer.Interval = 30
$twTimer.Add_Tick({
    if (-not $script:status -or (Ocupado)) { return }
    $script:twTick++
    $escribiendo = $script:twPos -lt $script:twTexto.Length
    if ($escribiendo) { $script:twPos = [Math]::Min($script:twTexto.Length, $script:twPos + $script:skin.Velocidad) }
    $txt = $script:twTexto.Substring(0, $script:twPos)
    if ($script:skin.Estilo -eq 'hacker' -and ($escribiendo -or ([Math]::Floor($script:twTick / 15) % 2 -eq 0))) { $txt += '_' }
    if ($script:status.Text -ne $txt) { $script:status.Text = $txt; Ajustar-Texto }
    Leer-Texto $escribiendo
    # Angela mueve la boca mientras escribe
    if ($script:pb -and $script:caras.Count -gt 0 -and -not $script:dInvitadoHabla) {
        $set = $script:caras[$script:caraModo]
        $img = if ($escribiendo -and ([Math]::Floor($script:twTick / 3) % 2 -eq 1)) { $set[1] } else { $set[0] }
        if ($script:pb.Image -ne $img) { $script:pb.Image = $img }
    }
})

function Decir($texto, $cara) {
    $script:twTexto = [string]$texto; $script:twPos = 0
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
            Decir ("*Cae al suelo muy dramáticamente.* $l")
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
    $form.Invalidate((New-Object System.Drawing.Rectangle([int](400 * $Z), [int](56 * $Z), [int](($form.ClientSize.Width / $Z - 400) * $Z), [int]($alto * $Z))))
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
    if ($script:estamina -lt 110) { $script:estamina = [Math]::Min(110, $script:estamina + 0.3); $hay = $true }
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
    return @((643 + $ox), (58 + $oy))
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
    Decir (Azar @('¡Un pajarito en la cabeza! Ahora sí que tengo cerebro de pájaro. ¡BIRDBRAIN!', '¡Hiii~! ...¿por qué me miráis todos? ¿Tengo algo en el pelo?', '¡Cinco pajaritos! Uno se ha quedado a vivir aquí arriba. Se llama Pan.'))
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
function Token-Clic {
    $a = $script:actores['K']; if ($a) { $a.Temblor = 10 }
    $script:tkHype = [Math]::Min(100, $script:tkHype + 22)
    Sonido 'golpe'; Token-Palabra
    if ($script:tkHype -ge 100) { Token-Breakcore } else { Decir (Azar $script:skin.Clic) }
    $form.Invalidate()
}
function Token-Breakcore {
    $script:tkHype = 0; $script:tkFx = 60
    Sonido 'breakcore'; Sacudir $form 12
    for ($i = 0; $i -lt 4; $i++) { Token-Palabra }
    Decir (Azar @('¡¡BREAKCORE MODE!! *Todo tiembla. Token está feliz.*', '¡DROP! *Las ventanas vibran a 200 BPM.*', '¡¡MÁS ALTO!! *Se le cae una oreja. Se la vuelve a poner sin dejar de bailar.*'))
}
function Token-Tick {
    $hay = $false
    if ($script:tkHype -gt 0) { $script:tkHype = [Math]::Max(0, $script:tkHype - 0.35); $hay = $true }
    if ($script:tkFx -gt 0) {
        $script:tkFx--; $hay = $true
        $a = $script:actores['K']; if ($a -and $script:tkFx % 5 -eq 0) { $a.Temblor = 5 }
        if ($script:tkFx % 9 -eq 0) { Token-Palabra }
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
# ================= ANIMACIÓN DE FONDO (planta rodadora, agua de Dune) =================
$script:fase = 0.0; $script:tumbX = -300; $script:salto = 0
$ambTimer = New-Object System.Windows.Forms.Timer
$ambTimer.Interval = 50
$ambTimer.Add_Tick({
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
    if ($k.Estilo -eq 'femta') { Token-Tick }
    if ($k.Estilo -eq 'pop') { Tetra-Tick }
})

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
    , @(@('Zodiac', '¡No te muevas, bicho del bosque!'), @('Pursuer', '*Se vuelve invisible.*'), @('Zodiac', '¿¡Dónde está!? ¡NO TE MUEVAS, DONDE SEA QUE ESTÉS!'), @('Pursuer', '*Detrás de él.* ...te veo.'))
)

$script:discutiendo = $false; $script:dLineas = $null; $script:dIdx = 0; $script:dImg = $null; $script:dInvitadoHabla = $false
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
    if (-not $f -or $f.IsDisposed -or $script:glitching -or $script:drag) { return }
    foreach ($s in $script:temblores) { if ($s.F -eq $f) { $s.T = [Math]::Max($s.T, $ticks); return } }
    [void]$script:temblores.Add(@{ F = $f; Base = $f.Location; T = $ticks }); $shkTimer.Start()
}
$script:humoF = $null
$humo2Timer = New-Object System.Windows.Forms.Timer
$humo2Timer.Interval = 1600
$humo2Timer.Add_Tick({ $humo2Timer.Stop(); if ($script:humoF -and -not $script:humoF.IsDisposed) { $script:humoF.Opacity = $(if ($script:humoF -eq $form) { (Opacidad-Base) } else { 1.0 }) } })
function Humo($f) { if (-not $f) { return }; $f.Opacity = 0.3; $script:humoF = $f; $humo2Timer.Stop(); $humo2Timer.Start() }

# --- ventanita del invitado ---
function Colocar-Invitado {
    $f = $script:inv; if (-not $f -or $f.IsDisposed) { return }
    $b = $form.Bounds; $e = 1 - [Math]::Pow(1 - [Math]::Min(1.0, $script:invAnim / 10.0), 3)
    $off = (1 - $e) * 40 * $script:K
    $x = if ($script:invLado -gt 0) { $b.Right + 8 * $script:K - $off } else { $b.Left - $f.Width - 8 * $script:K + $off }
    $f.Location = New-Object System.Drawing.Point([int]$x, [int]($b.Top + 30 * $script:K))
    $f.Opacity = [Math]::Max(0.0, $e)
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
        'femta' { Sonido-De $nombre 'golpe' }
        'pop' { Sonido-De $nombre 'ping' }
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
        'teto' { $ray = New-Object System.Drawing.Pen((C 252 232 236), 8); for ($x = -$H; $x -lt $W; $x += 26) { $g.DrawLine($ray, $x, 32, ($x + $H), ($H + 32)) }; $ray.Dispose(); $cab = (C 214 40 64) }
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
            'teto' { for ($i = 0; $i -lt 3; $i++) { Texto-Contorno $g '♪' 'Segoe UI Symbol' 20 (40 + $i * 60) (130 - (14 - $fx) * 7) (@((C 214 40 64), (C 246 170 30), (C 255 255 255))[$i]) 3 ([Math]::Min(255, $fx * 18)) } }
        }
    }
    $g.DrawRectangle((New-Object System.Drawing.Pen($acento, 3)), 1, 1, ($W - 3), ($H - 3))
}

$invTimer = New-Object System.Windows.Forms.Timer
$invTimer.Interval = 30
$invTimer.Add_Tick({
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
    $esInv = $quien -ne $script:skinNombre
    $f = if ($esInv) { $script:inv } else { $form }
    if ($txt -match 'BANG') { Sonido-De 'Zodiac' 'bang'; Sacudir $form 10; Sacudir $script:inv 10; if ($esInv) { $script:invFx = 8 } }
    elseif ($txt -match 'Smokebomb') { Sonido-De 'Mikaela' 'humo'; Humo $f }
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
    $yo = $script:skinNombre
    $cands = @($Discusiones | Where-Object { @($_ | ForEach-Object { $_[0] }) -contains $yo })
    if ($cands.Count -eq 0) { return }
    $script:dLineas = $cands[$Rnd.Next($cands.Count)]
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
            { $_ -in @('mew', 'mlg', 'tele', 'oeste') } { if ($Rnd.Next(2) -eq 0) { Cara 'clic' 1600 } }
        }
    } else {
        if ($script:skin.Estilo -eq 'hacker') { Glitch 3 "> $txt" } else { Decir $txt 'abiertos' }
    }
    Efectos-Linea $quien $txt
    $dTimer.Interval = [Math]::Max(2400, 1500 + $txt.Length * 55)
    $dTimer.Start()
}

function Fin-Discusion($rapido = $false) {
    $dTimer.Stop()
    $eraDiscusion = $script:discutiendo
    $script:discutiendo = $false; $script:dInvitadoHabla = $false
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
    $script:gTicks = $ticks; $script:gAccion = $accion; $script:gBase = $form.Location
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
function Logo-Inicio {
    $script:lgImg = if (Test-Path (Ruta 'skins\logo\logo.png')) { Cargar-Img 'skins\logo\logo.png' } else { $null }
    $script:lgImg2 = if (Test-Path (Ruta 'skins\logo\tung.png')) { Cargar-Img 'skins\logo\tung.png' } else { $null }
    $script:iRecursos = @($script:lgImg, $script:lgImg2)
    $script:iDespues = { Efecto-Entrada $null }
    $pintar = {
        param($g, $W, $H, $p)
        $g.Clear([System.Drawing.Color]::Black)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAlias'
        # aparece poco a poco y se apaga al final
        $a = if ($p -lt 20) { $p / 20.0 } elseif ($p -gt 112) { [Math]::Max(0.0, (128 - $p) / 16.0) } else { 1.0 }
        $alto = if ($script:lgImg) { $H * 0.56 } else { 0 }
        if ($script:lgImg) {
            # el panda y, a su lado, su compañero; los dos con los pies a la misma altura
            $z = 1 + $p * 0.0008
            $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$a
            $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
            $dh = $alto * $z; $dw = $script:lgImg.Width * $dh / $script:lgImg.Height
            $suelo = $H * 0.66 - 8; $th2 = [Math]::Min($dh * 1.12, $suelo - 6); $dh = [Math]::Min($dh, $th2 / 1.12); $dw = $script:lgImg.Width * $dh / $script:lgImg.Height; $tw2 = if ($script:lgImg2) { $script:lgImg2.Width * $th2 / $script:lgImg2.Height } else { 0 }
            $total = $dw + $(if ($script:lgImg2) { $tw2 - $dw * 0.06 } else { 0 })
            $x0 = $W / 2 - $total / 2
            $g.DrawImage($script:lgImg, (New-Object System.Drawing.Rectangle([int]$x0, [int]($suelo - $dh), [int]$dw, [int]$dh)), 0, 0, $script:lgImg.Width, $script:lgImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
            if ($script:lgImg2) { $g.DrawImage($script:lgImg2, (New-Object System.Drawing.Rectangle([int]($x0 + $dw * 0.94), [int]($suelo - $th2), [int]$tw2, [int]$th2)), 0, 0, $script:lgImg2.Width, $script:lgImg2.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia) }
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
    $form.Controls.Add($ov); $ov.BringToFront()
    $script:iOv = $ov; $script:iPaso = 0; $script:iTotal = $total; $script:iFinal = $final
    $iTimer.Start()
}

# --- "GUILLOTINA IS COMING FOR YOU!": el cementerio de noche y la radio WMEW 99.9 ---
function Transicion-Boss($final) {
    $script:bFondo = Cargar-Img $script:skin.IntroImg
    $script:bCartel = Cargar-Img $script:skin.Cartel
    $script:iRecursos = @($script:bFondo, $script:bCartel)
    $script:bLeyenda = 'WMEW 99.9: "Para mi asombro, parece que... una enorme aparición felina se dirige directa hacia esa casa de la colina..."'
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBilinear'
        $sx = 0; $sy = 0; if ($p -ge 10 -and $p -le 18) { $sx = $Rnd.Next(-8, 9); $sy = $Rnd.Next(-6, 7) }
        if ($script:bFondo) { Imagen-Cubrir $g $script:bFondo (-12 + $sx) (-8 + $sy) ($W + 24) ($H + 16) 0.4 0.5 } else { $g.Clear((C 30 10 12)) }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 70, 8, 12))), 0, 0, $W, $H)
        # rayos rojos girando detrás de ella
        $cx = $W * 0.72; $cy = $H / 2; $rot = $p * 2.5
        $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 160, 20, 20))
        for ($i = 0; $i -lt 18; $i++) {
            $a1 = [Math]::PI / 180 * ($rot + $i * 20 - 5); $a2 = [Math]::PI / 180 * ($rot + $i * 20 + 5)
            $g.FillPolygon($br, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$cx, [float]$cy)), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a1)), [float]($cy + 900 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a2)), [float]($cy + 900 * [Math]::Sin($a2))))))
        }
        $br.Dispose()
        # Guillotina entra desde la derecha y aterriza con golpe
        if ($script:bCartel) {
            $t = [Math]::Min(1.0, $p / 10.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            $ch = 300; $cw = $script:bCartel.Width * $ch / $script:bCartel.Height
            $g.DrawImage($script:bCartel, [int](($W + 20) - $e * ($cw + 40) + $sx), [int](8 + $sy), [int]$cw, [int]$ch)
        }
        if ($p -ge 10) { $tam = 58 + [Math]::Max(0, 16 - $p) * 6; Texto-Contorno $g 'GUILLOTINA' 'EdmundMcMillen_INTLv4' $tam 24 18 (C 245 235 210) 9 }
        if ($p -ge 18) { Texto-Contorno $g 'IS COMING' 'EdmundMcMillen_INTLv4' 44 30 100 (C 255 214 60) 8 }
        if ($p -ge 24) { Texto-Contorno $g 'FOR YOU!' 'EdmundMcMillen_INTLv4' 54 28 150 (C 235 50 40) 9 }
        if ($p -ge 30) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 10, 6, 8))), 0, ($H - 56), $W, 56)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 170 40 35))), 0, ($H - 56), $W, 3)
            $n = [Math]::Min($script:bLeyenda.Length, ($p - 30) * 4)
            $g.DrawString($script:bLeyenda.Substring(0, $n), (FntP('TikaFont Adjusted', 10.5, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 240 228 200))), (New-Object System.Drawing.RectangleF(14, ($H - 50), ($W - 28), 48)))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 1) { Sonido 'radio' }; if ($p -eq 10) { Sonido 'intro'; Sonido 'furia' }; if ($p -gt 70) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 76 $pintar $alTick $final
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

# --- INSERT TOKEN: estática, la ficha cae en la recreativa, el logo, cortes a toda velocidad y el cartel final ---
function Transicion-Token($final) {
    $script:tkImg = Cargar-Img $script:skin.Gif; $script:tkLogo = Cargar-Img $script:skin.Logo
    $script:tkR = Imagen-Color $script:tkImg (C 255 30 50) 300; $script:tkC = Imagen-Color $script:tkImg (C 40 230 255) 300
    $script:tkLB = Imagen-Color $script:tkLogo (C 255 255 255) 300; $script:tkLR = Imagen-Color $script:tkLogo (C 255 30 50) 300; $script:tkLC = Imagen-Color $script:tkLogo (C 40 230 255) 300
    $script:iRecursos = @($script:tkImg, $script:tkLogo, $script:tkR, $script:tkC, $script:tkLB, $script:tkLR, $script:tkLC)
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
            # 2) el logo entra de golpe con los colores separados
            $g.Clear($(if ($p -in @(12, 13)) { (C 120 0 14) } else { (C 6 4 6) }))
            $e = [Math]::Max(1.0, 2.0 - ($p - 12) * 0.25)
            $lh = 200 * $e; $lw = $script:tkLB.Width * $lh / $script:tkLB.Height
            $jx = $rn.Next(-6, 7); $sep = 4 + [Math]::Max(0, 18 - ($p - 12) * 2)
            Dibujar-RGB $g $script:tkLB $script:tkLR $script:tkLC ($W / 2 - $lw / 2 + $jx) ($H / 2 - $lh / 2 - 10) $lw $lh $sep
            for ($i = 0; $i -lt 5; $i++) { $g.FillRectangle((New-Object System.Drawing.SolidBrush((ARGB 140 230 20 40))), 0, $rn.Next(0, $H), $W, $rn.Next(1, 5)) }
            if ($p -ge 16) { Texto-Color $g 'femtanyl' 'Consolas' 18 ($W / 2 - 46) ($H - 50) (C 255 255 255) (C 230 20 40) 3 }
        } elseif ($p -lt 52) {
            # 3) cortes rápidos: una palabra y Token en otra postura cada pocos fotogramas
            $c = [int](($p - 24) / 3); $rc = New-Object System.Random ($c * 7 + 3)
            $g.Clear($(if ($c % 2 -eq 0) { (C 6 4 6) } else { (C 70 0 10) }))
            $th = 150 + $rc.Next(0, 160); $tw = $script:tkImg.Width * $th / $script:tkImg.Height
            $tx = $rc.Next(-40, [int]($W - $tw + 40)); $ty = $rc.Next(-30, [int]([Math]::Max(-29, $H - $th + 30)))
            $st = $g.Save(); $g.TranslateTransform([float]($tx + $tw / 2), [float]($ty + $th / 2)); $g.RotateTransform([float]$rc.Next(-25, 26)); if ($rc.Next(2) -eq 0) { $g.ScaleTransform(-1, 1) }
            Dibujar-RGB $g $script:tkImg $script:tkR $script:tkC (-$tw / 2) (-$th / 2) $tw $th (6 + $rc.Next(0, 8))
            $g.Restore($st)
            $pal = $TokenPalabras[$c % $TokenPalabras.Count]
            $st = $g.Save(); $g.TranslateTransform([float]$rc.Next(40, 380), [float]$rc.Next(60, [int]($H - 60))); $g.RotateTransform([float]$rc.Next(-12, 13))
            Texto-Color $g $pal 'Arial Black' (40 + $rc.Next(0, 22)) 0 0 (C 255 255 255) (C 230 20 40) 6
            $g.Restore($st)
            $sl = New-Object System.Drawing.Pen((ARGB 60 0 0 0), 1); for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($sl, 0, $y, $W, $y) }; $sl.Dispose()
        } else {
            # 4) cartel final: rayos rojos, Token y su nombre
            $g.Clear((C 6 4 6))
            $cx = $W * 0.68; $cy = $H * 0.5; $rot = $p * 3
            $br = New-Object System.Drawing.SolidBrush((ARGB 90 230 20 40))
            for ($i = 0; $i -lt 14; $i++) {
                $a1 = [Math]::PI / 180 * ($rot + $i * 25.7 - 6); $a2 = [Math]::PI / 180 * ($rot + $i * 25.7 + 6)
                $g.FillPolygon($br, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([float]$cx, [float]$cy)), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a1)), [float]($cy + 900 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF([float]($cx + 900 * [Math]::Cos($a2)), [float]($cy + 900 * [Math]::Sin($a2))))))
            }
            $br.Dispose()
            $th = $H * 0.86; $tw = $script:tkImg.Width * $th / $script:tkImg.Height
            Dibujar-RGB $g $script:tkImg $script:tkR $script:tkC ($cx - $tw / 2 + $rn.Next(-2, 3)) ($H - $th - 6) $tw $th (3 + ($p % 3))
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
            # botón negro con borde rojo; al pasar el ratón se pone rojo y el texto se separa en colores
            $g.SmoothingMode = 'AntiAlias'
            $g.Clear($(if ($enBarra) { (C 0 0 0) } else { (C 8 4 6) }))
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($(if ($hover) { (C 230 20 40) } else { (C 16 8 10) }))), 0, 0, $W, $H)
            $g.DrawRectangle((New-Object System.Drawing.Pen($(if ($hover) { (C 255 255 255) } else { (C 230 20 40) }), [float](2 * $Z))), [float]$Z, [float]$Z, [float]($W - 2 * $Z), [float]($H - 2 * $Z))
            if ($hover) {
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 40 230 255))), (New-Object System.Drawing.RectangleF([float](2 * $Z), 0, $W, $H)), $fmt)
                $g.DrawString($b.Text, $b.Font, (New-Object System.Drawing.SolidBrush((C 120 0 10))), (New-Object System.Drawing.RectangleF([float](-2 * $Z), 0, $W, $H)), $fmt)
            }
            $g.DrawString($b.Text, $b.Font, [System.Drawing.Brushes]::White, $rect, $fmt)
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
        Start-Process $item.Abrir -ErrorAction Stop
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
            'teto' {
                Teto-Pajaro
                $nv = @{ 'YouTube' = 'youtube'; 'Word' = 'word'; 'Excel' = 'excel'; 'Teams' = 'teams' }[$item.Nombre]
                if ($nv) { Sonido $nv } else { Sonido (Azar @('okay', 'letsgo', 'yay')) }
                $script:tetoVozT = [Environment]::TickCount
                Decir $linea
            }
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
            Start-Process $item.Web
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
                'teto' { Sonido 'oops'; Decir "¡No encuentro $($item.Nombre)! Te abro la web. ...¿qué estábamos buscando?" }
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
                'teto' { Sonido 'uhoh'; Decir "¡$($item.Nombre) se ha ido volando! Como un pájaro. Igual vuelve." }
                default { Decir "No encuentro $($item.Nombre). Igual nunca existió." }
            }
        }
    }
}

function Mostrar-Pagina {
    $grid.Controls.Clear()
    $script:bi = 0
    $hacker = $script:skin.Estilo -in @('hacker', 'lobo', 'mlg', 'gunsaw')
    if ($script:modoSkins) {
        $i = 0
        # las filas se encogen para que quepan todas las skins
        $filas = [Math]::Ceiling($Skins.Count / 3); $paso = [Math]::Min(34, [Math]::Floor(166 / $filas)); $altoB = $paso - 4
        foreach ($n in $Skins.Keys) {
            $txt = if ($n -eq $script:skinNombre) { "[ $n ]" } else { $n }
            $b = Nuevo-Boton $txt (($i % 3) * 128) ([Math]::Floor($i / 3) * $paso) 120 $altoB
            # los nombres largos usan letra más pequeña y caben en dos líneas
            if ($txt.Length -gt 12) { $b.Font = Fnt($b.Font.FontFamily.Name, 7.5, $b.Font.Style) }
            $b.Tag = $n
            $b.Add_Click({ Aplicar-Skin $this.Tag })
            # al pasar el ratón, el asistente opina de esa skin
            $b.Add_MouseEnter({ if (-not (Ocupado)) { Decir (Opinion $this.Tag) 'abiertos' } })
            if ($hacker) { Hover-Color $b }
            Escalar $b; $grid.Controls.Add($b); $i++
        }
        $script:lblPag.Text = 'Skins'
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
    $inicio = $script:pagina * $PorPagina
    $fin = [Math]::Min($inicio + $PorPagina, $Botones.Count) - 1
    $i = 0
    foreach ($item in $Botones[$inicio..$fin]) {
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
    if (-not $script:aj.Intros) { Decir $msg 'abiertos'; return }
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
        'femta' { Transicion-Token $msg }
        'pop' { Transicion-Pop $msg }
    }
}

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
        { $_ -in @('culto', 'kaiju', 'zorro', 'mew', 'oeste', 'pressure', 'dod', 'teto', 'femta', 'pop') } {
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
        'femta' { Token-Clic }
        'pop' { Tetra-Clic }
    }
}
$mDown = {
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
    if ($script:actores.Count -gt 0 -and -not $script:drag) { $form.Cursor = $(if (Actor-En-Raton) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }) }
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
    $script:pajaros.Clear(); $script:birdbrains = 0; $script:duelo = $null
    # personajes dibujados y estado de las skins nuevas
    $actTimer.Stop(); $kRevTimer.Stop()
    Quitar-Actores
    if ($script:bmpEscena) { $script:bmpEscena.Dispose(); $script:bmpEscena = $null }
    $script:fe = 60; $script:seguidores = 0; $script:ritualFx = 0
    Kaiju-Reiniciar
    $script:antojo = 0
    $form.Controls.Clear()

    $T = if ($k.Top) { $k.Top } else { 0 }
    $conActores = [bool]$k.Actores
    $conGif = [bool]$k.Gif -and -not $conActores
    $W = if ($k.Ancho) { $k.Ancho } elseif ($conGif) { 616 } else { 408 }
    $form.Size = New-Object System.Drawing.Size($W, $k.Alto)
    $form.BackColor = $k.Fondo
    $form.Opacity = (Opacidad-Base)
    $form.Text = $script:skinNombre

    $xTit = if ($k.Estilo -eq 'web') { 48 } else { 12 }
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
    $bSkins.Add_Click({ if (-not (Ocupado)) { $script:modoSkins = -not $script:modoSkins; Mostrar-Pagina } })
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
    $bAnt.Add_Click({ if ($script:pagina -gt 0) { $script:modoSkins = $false; $script:pagina--; Mostrar-Pagina } })
    $bSig = Nuevo-Boton '>' 272 (242 + $T) 120 28
    $bSig.Add_Click({ if ($script:pagina -lt $totalPaginas - 1) { $script:modoSkins = $false; $script:pagina++; Mostrar-Pagina } })

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
    $script:twTexto = ''; $script:twPos = 0; $status.Text = ''
    $form.Invalidate()
}

Construir-UI
# recordar dónde estaba la ventana
if ($script:aj.Posicion -and $script:aj.X -ne '' -and $script:aj.Y -ne '') {
    $pt = New-Object System.Drawing.Point([int]$script:aj.X, [int]$script:aj.Y)
    if ([System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.WorkingArea.Contains($pt) }) { $form.StartPosition = 'Manual'; $form.Location = $pt }
}
$form.Add_FormClosing({ if ($form.WindowState -eq 'Normal') { $script:aj.X = $form.Left; $script:aj.Y = $form.Top }; Guardar-Ajustes })
$form.Add_Shown({
    $twTimer.Start(); $idleTimer.Start(); $ambTimer.Start(); $hambreTimer.Start()
    Aplicar-Ajustes
    # primero el logo de JOSEPABLINI CORPORATION y luego la intro de la skin
    if ($script:aj.Intros) { Logo-Inicio } else { Efecto-Entrada $null }
})
[void]$form.ShowDialog()
