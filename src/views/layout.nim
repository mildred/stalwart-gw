import templates
import ../common

func layout*(com: CommonRequest, main, title: string): string = tmpli html"""
  <html>
    <head>
      <title>$title - Accounts</title>
      <link rel="stylesheet" href="https://unpkg.com/mvp.css">
    </head>
    <body>
      <header>
        <h1>$title</h1>
      </header>
      $main
    </body>
  </html>
  """


