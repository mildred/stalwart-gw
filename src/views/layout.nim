import templates
import ../common

func layout*(com: CommonRequest, main, title: string): string = tmpli html"""
  <html>
    <head>
      <title>$title - Accounts</title>
      <link rel="stylesheet" href="https://unpkg.com/mvp.css">
      <style>
        form[role=none] {
          display: inline;
          border: none;
          padding: 0;
          margin: 0;
        }
        [role=link] {
          display: inline-block;
          padding: 0;
          margin: 0;
          border: none;
          cursor: pointer;
          color: var(--color-secondary);
          font-weight: bold;
        }
        [role=link]:hover {
          filter: brightness(var(--hover-brightness));
          text-decoration: underline;
        }
      </style>
    </head>
    <body>
      <header>
        <h1>$title</h1>
      </header>
      $main
    </body>
  </html>
  """


