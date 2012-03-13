#include <imu_comm.h>
#include <sys/time.h>
#include <time.h>
#include <sys/types.h>
#include <unistd.h> // For STDIN_FILENO
#include <stdio.h>

#define IMU_COMM_TEST_EXIT_CHAR 'q'
#define IMU_COMM_TEST_CALIB_CHAR 'c'
#define IMU_COMM_TEST_CALIB_SHOW_CHAR 's'
#define IMU_COMM_TEST_HOW_TO "\nIncorrect arguments!\nUsage: ./imu_comm_test /dev/tty# log_to_file\n\nIf last argument is supplied (it can be any string) then the program will log raw data and\n processed data to two files, named according to the current timestamp."
#define WAIT_COUNTER_MAX 10
#define IMU_COMM_TEST_EOL_LIM 128

#define wait_for_enter printf("ERROR!\n") //while(fread(tmp,1,1,stdin) == 0)

static int fix_end_of_time_string(char * string, int lim){
    int i;
    if(lim<0)
	return -1;
    for(i=0;i<lim;++i){
	if(string[i]!='\n')
	    continue;
	break;
    }
    if(i==lim){
	fprintf(stderr,"Failed to fix time string");
	return ERROR_FAIL;
    }else{
	string[i]='\0';
    }	
    return ERROR_OK;
}

static int generate_log_name(char * log_name, char * start_string){
    time_t rawtime;
    struct tm * tm;
    int retval;
    time(&rawtime);
    tm = localtime (&rawtime);
    retval = sprintf(log_name,"%04d_%02d_%02d_xx_%02d_%02d_%02d", 1900 + tm->tm_year, tm->tm_mon + 1,tm->tm_mday, tm->tm_hour, tm->tm_min, tm->tm_sec);
    if(retval < 0)
	return ERROR_FAIL;
    if(start_string != NULL)
	retval = sprintf(log_name,"%s%s",start_string,log_name);
    return retval;
}

int main(int argc, char *argv[]){
    int retval;
    FILE * output_frames = NULL;
    FILE * output_avg = NULL;
    unsigned char tmp[2];
    char * device;
    char log_name[FILENAME_MAX];
    char log_filename[FILENAME_MAX];
    struct imu * imu = NULL;
    fd_set rfds;
    struct timeval tv;

    if(argc<2){
	fprintf(stderr,IMU_COMM_TEST_HOW_TO);
	exit(1);
    }else{
	device = argv[1];
    }
    if(argc<3){
	fprintf(stdout,"Using stdout to output...\n");
    }else{
	int i;
	retval = generate_log_name(log_name,NULL);
	if(retval < 0){
	    fprintf(stderr,"Failed to create log name...");
	    exit(1);
	}
   
	// Setup frame log
	sprintf(log_filename,"./logs/%s.log",log_name);
	output_frames = fopen(log_filename,"w");
	if(output_frames == NULL){
	    fprintf(stderr,"Failed to create frame log file...");
	    exit(1);
	}
	fprintf(stdout,"Sending frame output to log file: %s\n",log_name);

	// Setup avg log
	retval = sprintf(log_filename,"./logs/%savg.log",log_name);
	if(retval < 0){
	    fprintf(stderr,"Failed to create frame avg log file name...");
	    exit(1);
	}
	output_avg = fopen(log_filename,"w");
	if(output_avg == NULL){
	    fprintf(stderr,"Failed to create avg log file...");
	    exit(1);
	}
	fprintf(stdout,"Sending avg output to log file: %s\n",log_name);

    }

    // Initialize structure
    imu = imu_comm_init(device);
    if(imu==NULL){
	fprintf(stderr,"Fatal error.");
	exit(1);
    }

    // do stuff...
    imu_data_t data;
    imu_raw_t raw;
    imu_calib_t *imu_calib;
    uquad_bool_t do_sleep = false;
    int read_will_not_lock;
    int wait_counter = WAIT_COUNTER_MAX;
    int imu_fd;
    uquad_bool_t calibrating = false;
    data.acc = uquad_mat_alloc(3,1);
    data.gyro = uquad_mat_alloc(3,1);
    data.magn = uquad_mat_alloc(3,1);
    retval = imu_comm_get_fds(imu, &imu_fd);
    FD_ZERO(&rfds);
    //    printf("Options:\n'q' to abort,\n'c' to calibrate\n's' to display current calibration\n\n");
    while(1){
	if(do_sleep){
	    printf("Waiting...\n");
	    //	    usleep(1000*500); // Wait for a while... (0.5 sec)
	    printf("Running again.\n");
	    if(--wait_counter<0){
		// waited enough, now die
		printf("\nGave up on waiting, terminating program...\n");
		return -1;
	    }
	}else{
	    wait_counter = WAIT_COUNTER_MAX;
	}
	// Run loop until user presses any key or velociraptors chew through the power cable
	FD_SET(STDIN_FILENO,&rfds);
	FD_SET(imu_fd,&rfds);
	tv.tv_sec = 0;
	tv.tv_usec = 0;
	read_will_not_lock = select((STDIN_FILENO>imu_fd?STDIN_FILENO:imu_fd)+1,&rfds,NULL,NULL,&tv);
	if (read_will_not_lock < 0){
	    err_check(ERROR_IO,"select() failed!");
	}else{
	    // Read from IMU
	    if(FD_ISSET(imu_fd,&rfds)){
		do_sleep = false;
		retval = imu_comm_read(imu);
		if(retval == ERROR_READ_TIMEOUT){
		    printf("Not enough data available...\n");
		    do_sleep = true;
		    continue;// skip the rest of the loop
		}
		if(retval != ERROR_OK){
		    wait_for_enter;
		    continue;
		}

		if(imu_comm_get_status(imu) == IMU_COMM_STATE_RUNNING)
		{
#if 0
		    if(calibrating){
			// finished calibration
			calibrating = false;
			if(imu_comm_calibration_is_calibrated(imu)){
			    printf("Calibration successful!\n");
			    retval = imu_comm_calibration_get(imu,&imu_calib);
			    if(retval != ERROR_OK)
				printf("Failed to get calibration!");
			    else{
				// print a comment char to make it easy for matlab to parse the rest
				fprintf(output_avg,"%%");
				retval = imu_comm_print_data(&imu_calib,output_avg);
				if(retval != ERROR_OK)
				    printf("Failed to print calibration!");
			    }
			}else{
			    printf("Calibration FAILED...\n");
			    wait_for_enter;
			}
		    }
#endif	    
		    // Printing to stdout is unreadable
		    retval = imu_comm_get_raw_latest_unread(imu,&raw);
		    if(retval == ERROR_OK)
		    {
			retval = imu_comm_print_raw(&raw,stdout);
			err_propagate(retval);
		    }
		    retval = imu_comm_get_data_latest(imu,&data);
		    if(retval == ERROR_OK)
		    {
			retval = imu_comm_print_data(&data,stdout);
			err_propagate(retval);
		    }
		    
#if 0
			//TODO data is not ready
		    if(output_frames != NULL)
		    {
			retval = imu_comm_get_data_latest_unread(imu,&data);
			if(retval == ERROR_OK)
			{
			    retval = imu_comm_print_data(&data,output_frames);
			    err_propagate(retval);
			}
		    }
#endif
		    
		    // Get avg
#if 0
		    //TODO avg is KO!
		    if(imu_comm_avg_ready(imu)){
			retval = imu_comm_get_avg(imu,&data);
			err_propagate(retval);
			retval = imu_comm_print_data(&data,output_avg);
			err_propagate(retval);
		    }
#endif
		    if(output_frames == NULL || output_avg == NULL)
			fflush(stdout);
		}
	    }

	    // Handle user input
	    if(FD_ISSET(STDIN_FILENO,&rfds)){
		printf("\nGetting user input...\n");
		// Get & clear user input
		retval = fread(tmp,1,2,stdin);
		printf("Read:%c\n",tmp[0]);
		
		// exit
		if(tmp[0] == IMU_COMM_TEST_EXIT_CHAR)
		    break;
#if 0
		// do calibration
		if(tmp[0] == IMU_COMM_TEST_CALIB_CHAR){
		    printf("Starting calibration...\n");
		    calibrating = true;
		    retval = imu_comm_calibration_start(imu);
		    err_propagate(retval);
		}

		// display current calibration
		if(tmp[0] == IMU_COMM_TEST_CALIB_SHOW_CHAR){
		    if(!imu_comm_calibration_is_calibrated(imu)){
			printf("Calibration not ready.\n");
		    }else{
			retval = imu_comm_calibration_get(imu,&imu_calib);
			err_propagate(retval);
			printf("Current calibration:\n");
			retval = imu_comm_print_calib(&imu_calib,stdout);
			err_propagate(retval);
		    }
		}
#endif
		printf("\nPress enter to continue...\n");
		fflush(stdout);
		wait_for_enter;
	    }
	}
    }
		
    // Deinit structure & close connection
    retval = imu_comm_deinit(imu);
    err_propagate(retval);
    // Close log files, if any
    if(output_avg != NULL)
	fclose(output_avg);
    if(output_frames != NULL)
	fclose(output_frames);
    printf("Exit successful!\n");

    return 0;
}
    
