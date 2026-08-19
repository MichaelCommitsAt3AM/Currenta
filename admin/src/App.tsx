import { BrowserRouter } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { AuthOverlay } from './components/AuthOverlay'
import { useAdminSession } from './hooks/useAdminSession'

function App() {
  const auth = useAdminSession()

  return (
    <BrowserRouter>
      <div className="aurora" />
      {auth.phase === 'authenticated' ? <AppShell auth={auth} /> : <AuthOverlay auth={auth} />}
    </BrowserRouter>
  )
}

export default App
