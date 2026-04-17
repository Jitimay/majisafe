import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import * as pumpsApi from '../api/pumps.js';

export function usePumpStatus(stationId) {
  return useQuery({
    queryKey: ['pumpStatus', stationId],
    queryFn: () => pumpsApi.getStatus(stationId),
    refetchInterval: 30_000,
    enabled: Boolean(stationId),
  });
}

export function usePumpCommand(stationId) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ pump_number, action }) =>
      pumpsApi.sendCommand(stationId, { pump_number, action }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pumpStatus', stationId] });
    },
  });
}
