import templates
import ./layout
import ../common
import ../db/users

func layout_signed_nav(com: CommonRequest, main: string, message: string): string = tmpli html"""
    <header>
      <nav>
        <ul>
          <li><a href="$(com.prefix)/">Dashboard</a></li>
          <li><a href="$(com.prefix)/domains">Domains</a></li>
          <li><a href="$(com.prefix)/users/$(com.session.data.email)">$(com.session.data.email)</a></li>
          <li><a href="$(com.prefix)/logout">Log-Out</a></li>
        </ul>
      </nav>
    </header>
    <main>
      $if message != "" {
        <mark>$message</mark>
      }
      $main
    </main>
  """

func layout_signed*(com: CommonRequest, main, title: string, message: string = ""): string =
  result = com.layout(
    title = title,
    main = com.layout_signed_nav(main, message))


