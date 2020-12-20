/* ** Autor: Decio B. Júnior */
/* ** Data: 23-09-2014 */
/* ** Descrição: Corrige a reserva dos produtos ativos do Sankhya com base na especificação da Procedure STP_CORRIGEESTOQUERESERVADOPORPRODUTO */

DECLARE @CODPRODUTO INT
DECLARE @return_value INT

DECLARE corretor_reserva CURSOR FOR
    SELECT CODPROD
    FROM sankhya.TGFPRO

OPEN corretor_reserva

FETCH NEXT FROM corretor_reserva INTO @CODPRODUTO

WHILE @@FETCH_STATUS = 0
BEGIN	
	EXEC @return_value = [sankhya].[STP_CORRIGEESTOQUERESERVADOPORPRODUTO]
		@CODPROD = @CODPRODUTO
    FETCH NEXT FROM corretor_reserva INTO @CODPRODUTO
END
CLOSE corretor_reserva
DEALLOCATE corretor_reserva 