# c00lgui v3 - panel lanzador con skins de asistentes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# el panel mide su propio escalado de pantalla para que nada se corte
try {
    Add-Type -Namespace C00l -Name Dpi -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][C00l.Dpi]::SetProcessDPIAware()
} catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()

# TAMAÑO DEL PANEL: 1.0 = normal, 1.2 = un poco más grande, 1.5 = grande
$Tamano = 1.2
$gDpi = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$script:K = [float](($gDpi.DpiX / 96.0) * $Tamano)
$gDpi.Dispose()
# fuentes en píxeles: Fnt para controles (ya escalada), FntP para dibujos (los escala ScaleTransform)
function Fnt($a) {
    $st = if ($a.Count -ge 3) { $a[2] } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font([string]$a[0], [float]($a[1] * 96 / 72 * $script:K), $st, [System.Drawing.GraphicsUnit]::Pixel)
}
function FntP($a) {
    $st = if ($a.Count -ge 3) { $a[2] } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font([string]$a[0], [float]($a[1] * 96 / 72), $st, [System.Drawing.GraphicsUnit]::Pixel)
}
function Escalar($ctl) { $ctl.Scale((New-Object System.Drawing.SizeF($script:K, $script:K))) }
# cualquier error interno se convierte en un glitch/mensaje del panel en vez de una ventana de error
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)

$Raiz = $PSScriptRoot
$ArchivoSkin = Join-Path $Raiz 'skin.txt'
$Rnd = New-Object System.Random
$script:dia = (Get-Date).DayOfYear

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
)

# ================= SKINS =================
function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }

$Skins = [ordered]@{
    # ================================================================ c00lgui
    'c00lgui' = @{
        Estilo = 'hacker'; Titulo = 'c00lgui'; Sub = 'v3 // team c00lkidd'; Alto = 312
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
        StatusColor = (C 240 228 200); Fuente = 'Impact'; FuenteTitulo = 'Impact'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\guillotina\idle.gif'; GifClic = 'skins\guillotina\furia.gif'; GifFase2 = 'skins\guillotina\idle_furiosa.gif'
        Cartel = 'skins\guillotina\cartel.png'
        Sonidos = @{
            intro = @('skins\guillotina\intro.wav'); furia = @('skins\guillotina\furia.wav')
            golpe = @('skins\guillotina\golpe1.wav', 'skins\guillotina\golpe2.wav')
            comer = @('skins\guillotina\comer1.wav', 'skins\guillotina\comer2.wav')
        }
        Pb = @(410, 86, 190, 134); PbFondo = $null; PbBorde = $false
        Burbuja = @(410, 226, 190, 72); BurFondo = (C 250 244 228); BurTexto = (C 25 20 22); BurFuente = 'Segoe Print'
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
        StatusColor = (C 60 34 18); Fuente = 'Georgia'; FuenteTitulo = 'Georgia'; Opacidad = 1.0; Velocidad = 1
        Gif = 'skins\zodiac\idle.gif'; GifClic = 'skins\zodiac\disparo.gif'
        Extra = @{ vacio = 'skins\zodiac\vacio.gif'; recarga = 'skins\zodiac\recarga.gif'; pose = 'skins\zodiac\pose.gif' }
        Cartel = 'skins\zodiac\cartel.png'
        Sonidos = @{
            loco = @('skins\zodiac\loco1.wav', 'skins\zodiac\loco2.wav', 'skins\zodiac\loco3.wav', 'skins\zodiac\loco4.wav')
            bang = @('skins\zodiac\bang.mp3')
        }
        Pb = @(410, 62, 190, 148); PbFondo = $null; PbBorde = $false
        Burbuja = @(410, 238, 190, 60); BurFondo = (C 245 230 196); BurTexto = (C 60 34 18); BurFuente = 'Georgia'
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
function Sonido-De($nombre, $clave) {
    $k = $Skins[$nombre]
    if (-not $k -or -not $k.Sonidos -or -not $k.Sonidos[$clave]) { return }
    try {
        $ruta = Ruta (Azar $k.Sonidos[$clave])
        if ($ruta -like '*.mp3') {
            # los mp3 se reproducen con el reproductor de Windows
            $mp = New-Object System.Windows.Media.MediaPlayer
            $mp.Open([Uri]$ruta); $mp.Play()
            [void]$script:reproductores.Add($mp)
            if ($script:reproductores.Count -gt 8) { $script:reproductores[0].Close(); $script:reproductores.RemoveAt(0) }
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
    $path.AddString($txt, (New-Object System.Drawing.FontFamily($fuente)), 0, $tam, (New-Object System.Drawing.PointF($x, $y)), [System.Drawing.StringFormat]::GenericDefault)
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
    if ($script:status.Text -ne $txt) { $script:status.Text = $txt }
    # Angela mueve la boca mientras escribe
    if ($script:pb -and $script:caras.Count -gt 0 -and -not $script:dInvitadoHabla) {
        $set = $script:caras[$script:caraModo]
        $img = if ($escribiendo -and ([Math]::Floor($script:twTick / 3) % 2 -eq 1)) { $set[1] } else { $set[0] }
        if ($script:pb.Image -ne $img) { $script:pb.Image = $img }
    }
})

function Decir($texto, $cara) {
    $script:twTexto = [string]$texto; $script:twPos = 0
    if ($script:caras.Count -gt 0) {
        if (-not $cara) { $cara = @('cerrados', 'abiertos')[$Rnd.Next(2)] }
        $script:caraModo = $cara
    }
}

function Saludo {
    $k = $script:skin
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

# ================= CARAS DEL ASISTENTE =================
function Img-Base {
    if ($script:skin.Estilo -eq 'mew') {
        if (-not $script:gVivo) { return $null }
        if ($script:gFase2) { return $script:imgs.fase2 }
    }
    return $script:imgs.main
}
$caraTimer = New-Object System.Windows.Forms.Timer
$caraTimer.Add_Tick({ $caraTimer.Stop(); if ($script:pb) { $script:pb.Image = (Img-Base) } })
function Cara($clave, $ms) {
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
    Sonido 'intro'
    Decir 'WMEW 99.9: ¡Guillotina ha vuelto, buscando venganza!'
    $form.Invalidate()
})
function Golpe-Guillotina {
    if (-not $script:gVivo) { Decir '*Ya no está. Pero volverá.*'; return }
    $d = $Rnd.Next(15, 41)
    $script:gHP -= $d
    if (-not $script:gFase2 -and $script:gHP -le 200) {
        # igual que en el juego: se enfurece, cura 50 y gana 100 de vida máxima
        $script:gFase2 = $true; $script:gHP += 50; $script:gMax += 100
        Sonido 'furia'; Cara 'clic' 2600
        Decir 'WMEW 99.9: ¡Está FURIOSA! ¡Recupera 50 de vida y crece todavía más!'
    } elseif ($script:gHP -le 0) {
        $script:gHP = 0; $script:gVivo = $false
        Sonido 'furia'
        if ($script:pb) { $caraTimer.Stop(); $script:pb.Image = $null }
        Decir '*Guillotina cae rodando...* ¡La has derrotado! Por ahora.'
        $revTimer.Start()
    } else {
        Sonido 'golpe'; Cara 'clic' 1400
        Decir "-$d HP. $(Azar $script:skin.Clic)"
    }
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
$humoTimer.Add_Tick({ $humoTimer.Stop(); $form.Opacity = $script:skin.Opacidad })

# ================= ZODIAC: REVÓLVER DE 6 BALAS =================
$script:balas = 6
function Zodiac-Disparo {
    if ($script:balas -gt 0) {
        $script:balas--; Sonido 'bang'; Cara 'clic' 1300
        $form.Invalidate(); return $true
    }
    Cara 'vacio' 1800
    return $false
}
function Zodiac-Mover {
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
    if (-not $script:skin.Hambre -or (Ocupado)) { return }
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

# ================= ANIMACIÓN DE FONDO (planta rodadora, agua de Dune) =================
$script:fase = 0.0; $script:tumbX = -300; $script:salto = 0
$ambTimer = New-Object System.Windows.Forms.Timer
$ambTimer.Interval = 50
$ambTimer.Add_Tick({
    $k = $script:skin; $Z = $script:K
    if ((Ocupado) -or -not $k) { return }
    $script:fase += 0.14
    if ($k.Estilo -eq 'oeste') {
        $script:tumbX += 4
        if ($script:tumbX -gt 680) { $script:tumbX = -60 - $Rnd.Next(0, 900) }
        if ($script:tumbX -gt -40) { $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](262 * $Z), $form.ClientSize.Width, [int](50 * $Z)))) }
    }
    if ($k.Agua -and $script:pb) {
        # Dune flota en el agua; da un saltito cuando come
        $extra = 0; if ($script:salto -gt 0) { $script:salto--; $extra = - [Math]::Sin($script:salto / 10.0 * [Math]::PI) * 12 }
        $script:pb.Top = [int](($k.Pb[1] + [Math]::Sin($script:fase) * 3 + $extra) * $Z)
        $form.Invalidate((New-Object System.Drawing.Rectangle(0, [int](296 * $Z), $form.ClientSize.Width, [int](20 * $Z))))
    }
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
$humo2Timer.Add_Tick({ $humo2Timer.Stop(); if ($script:humoF -and -not $script:humoF.IsDisposed) { $script:humoF.Opacity = $(if ($script:humoF -eq $form) { $script:skin.Opacidad } else { 1.0 }) } })
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
    $l.BackColor = if ($gk.BurFondo) { $gk.BurFondo } else { [System.Drawing.Color]::Black }
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
    $script:inv = $f; $script:invAnim = 0; $script:invSale = $false; $script:invFx = 14; $script:invTexto = ''; $script:invPos = 0
    Colocar-Invitado
    $f.Show()
    # cada invitado llega con su propio sonido
    switch ($gk.Estilo) {
        'oeste' { Sonido-De $nombre 'bang' }
        'mew' { Sonido-De $nombre 'golpe' }
        'mlg' { Sonido-De $nombre 'apuntar' }
        'hacker' { try { [System.Media.SystemSounds]::Hand.Play() } catch {} }
        default { try { [System.Media.SystemSounds]::Asterisk.Play() } catch {} }
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
    elseif ($txt -match 'NO TE MUEVAS|GRRGH|FURIOSA|denegada') { Sacudir $f 8 }
    if ($quien -eq 'Mikaela' -and $txt -match 'mira') { Sonido-De 'Mikaela' 'apuntar' }
    if ($quien -eq 'Guillotina' -and $txt -match 'boca') { Sonido-De 'Guillotina' 'golpe' }
    if ($quien -eq 'Static Miku' -and $esInv) { $script:invFx = 6 }
    if ($quien -eq 'c00lgui' -and $esInv) { $script:invFx = 8 }
}

function Iniciar-Discusion {
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
        $script:invTexto = $txt; $script:invPos = 0
        switch ($script:skin.Estilo) {
            'lobo' { $script:caraModo = 'serio' }
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
            if ($r -lt 32 -and $script:gVivo -and -not $script:gFase2) { Cara 'clic' 2500; Sonido 'golpe'; Decir '*Se pone furiosa sin motivo aparente.*' }
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
        $form.Opacity = $script:skin.Opacidad
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
    try { [System.Media.SystemSounds]::Hand.Play() } catch {}
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
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
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
        Decir $script:iFinal 'abiertos'
        return
    }
    if ($script:iTick) { & $script:iTick $script:iOv $script:iPaso }
    $script:iOv.Invalidate()
})

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

# --- "GUILLOTINA IS COMING FOR YOU!" ---
function Transicion-Boss($final) {
    $script:bCartel = $null
    $ruta = Ruta $script:skin.Cartel
    if (Test-Path $ruta) { $script:bCartel = [System.Drawing.Image]::FromFile($ruta) }
    $script:iRecursos = @($script:bCartel)
    $script:bLeyenda = 'WMEW 99.9: "Para mi asombro, parece que... una enorme aparición felina se dirige directa hacia esa casa de la colina..."'
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'
        $g.Clear((C 58 10 12))
        # rayos girando detrás del jefe
        $cx = $W * 0.74; $cy = $H / 2; $rot = $p * 2.5
        $br = New-Object System.Drawing.SolidBrush((C 105 20 20))
        for ($i = 0; $i -lt 18; $i++) {
            $a1 = [Math]::PI / 180 * ($rot + $i * 20 - 5); $a2 = [Math]::PI / 180 * ($rot + $i * 20 + 5)
            $pts = @((New-Object System.Drawing.PointF($cx, $cy)), (New-Object System.Drawing.PointF(($cx + 900 * [Math]::Cos($a1)), ($cy + 900 * [Math]::Sin($a1)))), (New-Object System.Drawing.PointF(($cx + 900 * [Math]::Cos($a2)), ($cy + 900 * [Math]::Sin($a2)))))
            $g.FillPolygon($br, [System.Drawing.PointF[]]$pts)
        }
        $br.Dispose()
        # retrato entrando desde la derecha con golpe
        if ($script:bCartel) {
            $t = [Math]::Min(1.0, $p / 8.0); $e = 1 - [Math]::Pow(1 - $t, 3)
            $x = ($W + 20) - $e * 320; $y = 10
            if ($p -ge 8 -and $p -le 15) { $x += $Rnd.Next(-7, 8); $y += $Rnd.Next(-6, 7) }
            $g.DrawImage($script:bCartel, [int]$x, [int]$y, 290, 288)
        }
        # textos
        if ($p -ge 10) { $tam = 50 + [Math]::Max(0, 14 - $p) * 5; Texto-Borde $g 'GUILLOTINA' 'Impact' $tam 22 22 (C 245 235 210) }
        if ($p -ge 16) { Texto-Borde $g 'IS COMING' 'Impact' 38 28 98 (C 255 214 60) }
        if ($p -ge 22) { Texto-Borde $g 'FOR YOU!' 'Impact' 46 26 146 (C 235 50 40) }
        if ($p -ge 28) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 0, 0, 0))), 0, ($H - 62), $W, 62)
            $n = [Math]::Min($script:bLeyenda.Length, ($p - 28) * 4)
            $g.DrawString($script:bLeyenda.Substring(0, $n), (FntP('Segoe UI', 8.5, [System.Drawing.FontStyle]::Italic)), [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(12, ($H - 58), ($W - 24), 54)))
        }
    }
    $alTick = { param($ov, $p) if ($p -eq 8) { Sonido 'intro' }; if ($p -gt 66) { $ov.Top -= [int]($ov.Height / 5) } }
    Intro-Overlay 72 $pintar $alTick $final
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

# --- cartel de SE BUSCA de Zodiac ---
function Transicion-Wanted($final) {
    $script:wpImg = Cargar-Img $script:skin.Cartel
    $script:iRecursos = @($script:wpImg)
    $script:agujeros = New-Object System.Collections.ArrayList
    $pintar = {
        param($g, $W, $H, $p)
        $g.SmoothingMode = 'AntiAlias'
        $g.Clear((C 52 30 16))
        $tabla = New-Object System.Drawing.Pen((C 38 20 9), 2)
        for ($x = 0; $x -lt $W; $x += 44) { $g.DrawLine($tabla, $x, 0, $x, $H) }
        $tabla.Dispose()
        $pw = 300; $ph = $H - 24; $px = [int]($W / 2 - $pw / 2); $py = 12
        if ($p -lt 8) { $py = 12 - [int]((1 - $p / 8.0) * ($H + 20)) }
        if ($p -gt 42) { $py = 12 + [int]([Math]::Pow($p - 42, 2) * 7) }
        $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 238 218 172))), $px, $py, $pw, $ph)
        $g.DrawRectangle((New-Object System.Drawing.Pen((C 150 105 55), 4)), $px, $py, $pw, $ph)
        $g.DrawRectangle((New-Object System.Drawing.Pen((C 120 80 40), 1)), ($px + 8), ($py + 8), ($pw - 16), ($ph - 16))
        $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'
        $tinta = New-Object System.Drawing.SolidBrush((C 70 40 20))
        $g.DrawString('WANTED', (FntP('Georgia', 26, [System.Drawing.FontStyle]::Bold)), $tinta, (New-Object System.Drawing.RectangleF(($px - 20), ($py + 12), ($pw + 40), 50)), $fmt)
        if ($script:wpImg) {
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 225 200 150))), ($px + $pw / 2 - 56), ($py + 62), 112, 146)
            $g.DrawImage($script:wpImg, [int]($px + $pw / 2 - 50), [int]($py + 64), 100, 140)
            $g.DrawRectangle((New-Object System.Drawing.Pen((C 70 40 20), 2)), ($px + $pw / 2 - 56), ($py + 62), 112, 146)
        }
        $g.DrawString('ZODIAC', (FntP('Georgia', 18, [System.Drawing.FontStyle]::Bold)), $tinta, (New-Object System.Drawing.RectangleF($px, ($py + 212), $pw, 32)), $fmt)
        $g.DrawString('DEAD OR ALIVE  ·  6 BALAS', (FntP('Georgia', 8, [System.Drawing.FontStyle]::Bold)), $tinta, (New-Object System.Drawing.RectangleF($px, ($py + 244), $pw, 18)), $fmt)
        foreach ($a in $script:agujeros) {
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 140 110 70))), ($px + $a.X - 9), ($py + $a.Y - 9), 18, 18)
            $g.FillEllipse([System.Drawing.Brushes]::Black, ($px + $a.X - 5), ($py + $a.Y - 5), 10, 10)
        }
        if ($p -ge 18 -and $p -le 42) {
            $st = $g.Save()
            $dx = if ($p -lt 23) { $Rnd.Next(-8, 9) } else { 0 }
            $g.TranslateTransform(($W / 2 + $dx), ($H / 2 + 30)); $g.RotateTransform(-14)
            Texto-Borde $g "DON'T MOVE!" 'Impact' 48 -150 -34 (C 210 40 30)
            $g.Restore($st)
        }
    }
    $alTick = {
        param($ov, $p)
        if ($p -eq 18) { Sonido 'loco' }
        if ($p -in @(25, 29, 33)) { Sonido 'bang'; [void]$script:agujeros.Add(@{ X = $Rnd.Next(30, 270); Y = $Rnd.Next(50, 250) }) }
    }
    Intro-Overlay 55 $pintar $alTick $final
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
            'mew' { if ($Rnd.Next(2) -eq 0) { Sonido 'comer' }; Decir $linea }
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
        foreach ($n in $Skins.Keys) {
            $txt = if ($n -eq $script:skinNombre) { "[ $n ]" } else { $n }
            $b = Nuevo-Boton $txt (($i % 3) * 128) ([Math]::Floor($i / 3) * 44) 120 36
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
    switch ($script:skin.Estilo) {
        'hacker' { Glitch 10 $msg }
        'web' { Transicion-Web $msg }
        'tele' { Transicion-Estatica $msg }
        'mew' { Transicion-Boss $msg }
        'lobo' { Transicion-Lobo $msg }
        'mlg' { Transicion-Scope $msg }
        'oeste' { Transicion-Wanted $msg }
        'gunsaw' { Transicion-Gunsaw $msg }
    }
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
        'mew' {
            $g.SmoothingMode = 'AntiAlias'
            # la casa de la colina: papel pintado, suelo de madera y foco sobre Guillotina
            if (-not $script:bmpCasa) { $script:bmpCasa = Fondo-Casa 616 344 }
            $g.DrawImage($script:bmpCasa, 0, 0, 616, 344)
            $luz = New-Object System.Drawing.Drawing2D.GraphicsPath; $luz.AddEllipse(380, 70, 250, 190)
            $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush($luz)
            $pg.CenterColor = [System.Drawing.Color]::FromArgb(120, 255, 226, 170); $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 226, 170))
            $g.FillPath($pg, $luz); $pg.Dispose(); $luz.Dispose()
            # barra de tinta con arañazos
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 28 21 24))), 0, 0, $W, 52)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 170 40 35))), 0, 52, $W, 4)
            $ar = New-Object System.Drawing.Pen((C 150 60 50), 3); $ar.StartCap = 'Round'; $ar.EndCap = 'Round'
            for ($i = 0; $i -lt 3; $i++) { $g.DrawLine($ar, (402 + $i * 12), 10, (390 + $i * 12), 42) }
            $ar.Dispose()
            # barra de vida del jefe con calavera
            $placa = Ruta-Redonda 405 58 200 26 10
            $g.FillPath((New-Object System.Drawing.SolidBrush((C 24 18 20))), $placa); $g.DrawPath((New-Object System.Drawing.Pen((C 120 40 35), 2)), $placa); $placa.Dispose()
            $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 240 228 200))), 409, 60, 22, 22)
            $g.FillEllipse([System.Drawing.Brushes]::Black, 414, 67, 5, 6); $g.FillEllipse([System.Drawing.Brushes]::Black, 421, 67, 5, 6)
            $g.FillRectangle([System.Drawing.Brushes]::Black, 417, 76, 6, 2)
            $hx = 436; $hy = 63; $hw = 164; $hh = 16
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 70 22 22))), $hx, $hy, $hw, $hh)
            $frac = if ($script:gMax -gt 0) { [Math]::Max(0, $script:gHP) / $script:gMax } else { 0 }
            $colVida = if ($script:gFase2) { (C 240 90 30) } else { (C 200 35 35) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($colVida)), $hx, $hy, [int]($hw * $frac), $hh)
            $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 255, 255, 255))), $hx, $hy, [int]($hw * $frac), 5)
            $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)), $hx, $hy, $hw, $hh)
            $etq = if (-not $script:gVivo) { 'DERROTADA' } elseif ($script:gFase2) { "¡FURIOSA!  $($script:gHP)/$($script:gMax)" } else { "$($script:gHP)/$($script:gMax)" }
            $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
            $g.DrawString($etq, (FntP('Impact', 9)), [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF($hx, $hy, $hw, $hh)), $fmt)
        }
        'gunsaw' {
            # pantalla CRT morada del menú de personajes de Gunsaw
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($k.Fondo)), 0, 0, $W, $H)
            $lin = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(16, 255, 255, 255), 1)
            for ($y = 0; $y -lt $H; $y += 3) { $g.DrawLine($lin, 0, $y, $W, $y) }
            $lin.Dispose()
            $g.SmoothingMode = 'AntiAlias'
            $gris = New-Object System.Drawing.Pen((C 125 112 130), 1)
            $g.DrawString('A-D to switch skins', (FntP('Consolas', 8, [System.Drawing.FontStyle]::Bold)), (New-Object System.Drawing.SolidBrush((C 200 195 205))), 300, 6)
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
        'oeste' {
            $g.SmoothingMode = 'AntiAlias'
            if (-not $script:bmpDesierto) { $script:bmpDesierto = Fondo-Desierto 616 344 }
            $g.DrawImage($script:bmpDesierto, 0, 0, 616, 344)
            # planta rodadora cruzando el desierto
            if ($script:tumbX -gt -40 -and $script:tumbX -lt ($W + 40)) {
                $st = $g.Save()
                $g.TranslateTransform([float]$script:tumbX, [float](292 - [Math]::Abs([Math]::Sin($script:tumbX / 30.0)) * 8)); $g.RotateTransform([float]($script:tumbX * 4))
                $rama = New-Object System.Drawing.Pen((C 128 88 44), 1.6)
                foreach ($a in @(0, 45, 90, 135)) { $g.RotateTransform(45); $g.DrawEllipse($rama, -12, -9, 24, 18) }
                $g.DrawEllipse((New-Object System.Drawing.Pen((C 100 66 32), 2)), -11, -11, 22, 22)
                $rama.Dispose(); $g.Restore($st)
            }
            # barra de madera del saloon
            $mad = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, 52)), (C 104 62 32), (C 72 40 20), 90)
            $g.FillRectangle($mad, 0, 0, $W, 52); $mad.Dispose()
            $tabla = New-Object System.Drawing.Pen((C 56 30 14), 1)
            foreach ($y in @(17, 35)) { $g.DrawLine($tabla, 0, $y, $W, $y) }
            foreach ($x in @(150, 330, 470)) { $g.DrawLine($tabla, $x, 0, $x, 17); $g.DrawLine($tabla, ($x - 60), 17, ($x - 60), 35); $g.DrawLine($tabla, ($x + 40), 35, ($x + 40), 52) }
            $tabla.Dispose()
            $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 36 18 8))), 0, 52, $W, 4)
            # cartuchos del revólver: 6 balas
            for ($i = 0; $i -lt 6; $i++) {
                $bx = 422 + $i * 30; $by = 213
                if ($i -lt $script:balas) {
                    $vaina = Ruta-Redonda $bx ($by + 6) 14 16 4
                    $g.FillPath((New-Object System.Drawing.SolidBrush((C 222 178 70))), $vaina); $g.DrawPath((New-Object System.Drawing.Pen((C 90 60 20), 1.5)), $vaina); $vaina.Dispose()
                    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 196 110 62))), $bx, $by, 14, 12)
                    $g.DrawEllipse((New-Object System.Drawing.Pen((C 90 50 25), 1.5)), $bx, $by, 14, 12)
                    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110, 255, 255, 255))), ($bx + 3), ($by + 8), 3, 12)
                } else {
                    $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160, 70, 40, 20), 2)), ($bx + 1), ($by + 6), 12, 12)
                }
            }
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
    $ancho = if ($k.Estilo -in @('tele', 'mew', 'oeste')) { 4 } elseif ($k.Estilo -eq 'lobo') { 2 } else { 3 }
    $pen = New-Object System.Drawing.Pen($k.Borde, $ancho)
    $g.DrawRectangle($pen, 1, 1, $W - 3, $H - 3); $pen.Dispose()
})

$script:drag = $false
$mDown = {
    $script:drag = $true; $script:p0 = [System.Windows.Forms.Cursor]::Position; $script:f0 = $form.Location
    # Zodiac dispara a todo lo que se mueve... incluida la ventana
    if ($script:skin.Estilo -eq 'oeste' -and -not (Ocupado)) { Zodiac-Mover }
}
$mMove = {
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
    $form.Controls.Clear()

    $T = if ($k.Top) { $k.Top } else { 0 }
    $conGif = [bool]$k.Gif
    $W = if ($conGif) { 616 } else { 408 }
    $form.Size = New-Object System.Drawing.Size($W, $k.Alto)
    $form.BackColor = $k.Fondo
    $form.Opacity = $k.Opacidad
    $form.Text = $script:skinNombre

    $xTit = if ($k.Estilo -eq 'web') { 48 } else { 12 }
    $estiloTit = if ($k.FuenteTitulo -eq 'Impact') { [System.Drawing.FontStyle]::Regular } else { [System.Drawing.FontStyle]::Bold }
    $titulo = New-Object System.Windows.Forms.Label
    $titulo.Text = $k.Titulo
    $titulo.Font = Fnt($k.FuenteTitulo, 20, $estiloTit)
    $titulo.ForeColor = $k.TituloColor
    $titulo.BackColor = [System.Drawing.Color]::Transparent
    $titulo.AutoSize = $true
    $titulo.Location = New-Object System.Drawing.Point($xTit, 6)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = $k.Sub
    $sub.Font = Fnt($(if ($k.Fuente -eq 'Impact') { 'Segoe UI' } else { $k.Fuente }), 8, [System.Drawing.FontStyle]::Bold)
    $sub.ForeColor = $k.SubColor
    $sub.BackColor = [System.Drawing.Color]::Transparent
    $sub.AutoSize = $true
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
    } else {
        $status.BackColor = [System.Drawing.Color]::Black
        $status.Add_MouseUp({ if ($_.Button -eq 'Right') { Iniciar-Discusion } })
        $status.Font = Fnt('Consolas', 8.5)
        $status.Location = New-Object System.Drawing.Point(14, 278)
        $status.Size = New-Object System.Drawing.Size(380, 22)
    }

    # todo se diseña a tamaño base y luego se escala de una vez (evita textos cortados)
    $loc = $form.Location
    Escalar $form
    $form.Location = $loc
    Mostrar-Pagina
    $script:twTexto = ''; $script:twPos = 0; $status.Text = ''
    $form.Invalidate()
}

Construir-UI
$form.Add_Shown({
    $twTimer.Start(); $idleTimer.Start(); $ambTimer.Start(); $hambreTimer.Start()
    Efecto-Entrada $null
})
[void]$form.ShowDialog()
