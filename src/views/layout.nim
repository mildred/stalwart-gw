import templates

func layout*(main, title: string): string = tmpli html"""
  <html>
    <head>
      <title>$title - Accounts</title>
    </head>
    <body>
      $main
    </body>
  </html>
  """


