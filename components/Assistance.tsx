'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useToast } from "@/components/hooks/use-toast"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"

type Delegate = {
  id: string
  name: string
  country: string
  emoji: string
  state: 'PRESENTE' | 'AUSENTE' | 'PRESENTE_Y_VOTANDO'
}

type AssistanceProps = {
  delegates: Delegate[]
  isRegistered: boolean
  sessionId: number
}

export default function Assistance({ delegates: initialDelegates, isRegistered, sessionId }: AssistanceProps) {
  const [delegates, setDelegates] = useState<Delegate[]>(initialDelegates)
  const [showConfirmDialog, setShowConfirmDialog] = useState(false)
  const { toast } = useToast()
  const router = useRouter()
  // console.log("SDAKDSLADSKLASMDKLASMKLDMAS")
  // console.log(sessionId)

  const handleStateChange = (delegateId: string, newState: Delegate['state']) => {
    setDelegates(prevDelegates =>
      prevDelegates.map(delegate =>
        delegate.id === delegateId ? { ...delegate, state: newState } : delegate
      )
    )
  }

  const handleSave = async () => {
    if (isRegistered) {
      toast({
        title: "Asistencia guardada previamente",
        description: `La asistencia para la sesion ${sessionId} ya fue registrada.`,
        variant: "destructive",
      })
      router.push(`/mocion?sessionId=${sessionId}`)
      return
    }

    if (!showConfirmDialog) {
      setShowConfirmDialog(true)
      return
    }

    try {
      const response = await fetch('/api/attendance', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          attendanceRecords: delegates.map(delegate => ({
            delegateId: delegate.id,
            sessionId: sessionId,
            state: delegate.state,
          })),
        }),
      })

      if (!response.ok) {
        throw new Error('Error al guardar la asistencia')
      }

      toast({
        title: "Asistencia guardada",
        description: "La asistencia se guardo con exito.",
      })
      router.push(`/mocion?sessionId=${sessionId}`)
    } catch (error) {
      console.error('Error saving attendance:', error)
      toast({
        title: "Error",
        description: "Failed to save attendance. Please try again.",
        variant: "destructive",
      })
    }
  }

  return (
    <>
      <Card className="w-full max-w-4xl mx-auto">
        <CardHeader>
          <CardTitle>Asistencia de los delegados</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {delegates.map(delegate => (
              <div key={delegate.id} className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <span>{delegate.emoji}</span>
                  <span>{delegate.name} - {delegate.country}</span>
                </div>
                <Select
                  value={delegate.state}
                  onValueChange={(value: Delegate['state']) => handleStateChange(delegate.id, value)}
                  disabled={isRegistered}
                >
                  <SelectTrigger className="w-[180px]">
                    <SelectValue placeholder="Select state" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="PRESENTE">Presente</SelectItem>
                    <SelectItem value="AUSENTE">Ausente</SelectItem>
                    <SelectItem value="PRESENTE_Y_VOTANDO">Presente y Votando</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            ))}
          </div>
        </CardContent>
        <CardFooter>
          <Button onClick={handleSave} disabled={isRegistered}>
            Guardar Asistencia
          </Button>
        </CardFooter>
      </Card>

      <AlertDialog open={showConfirmDialog} onOpenChange={setShowConfirmDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmaciónd eguardado de Asistencia</AlertDialogTitle>
            <AlertDialogDescription>
              ¿Esta seguro que desea guardar la asistencia?. Esta acción no se puede deshacer.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={handleSave}>Confirm</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}