#include <printf.h>
#include <Timer.h>
module TestBC {
	uses interface Boot;
	uses interface Leds;
	uses interface Packet;

	uses interface AMSend;
	uses interface Receive;
	uses interface SplitControl as AMControl;
	uses interface Timer<TMilli> as Timer0;   //周期性地发送自己的节点号，总共发送两次
	uses interface Timer<TMilli> as Timer1;
	//uses interface Timer<TMilli> as Timer2;
}

implementation {
    //节点号
	typedef nx_struct nodeMsg {
		nx_uint8_t node_id;
	}nodeMsg;

	//发送的最大节点号或者最小节点号
	typedef nx_struct dataMsg {
		nx_uint8_t data[10];    //存了数据
		nx_bool mxmi;           //判断发送的是TRUE最大值，还是FLASE最小值
		nx_bool renewmxmi;      //判断是否是最终的包
	}dataMsg;

	uint8_t data[50];      //存放单个节点号
	uint8_t max[10];       
	uint8_t min[10];
	uint8_t middle[10];       //暂时存放比较自己的数组和收到的数组的比较结果
	uint8_t counter = 1;     //收到的单个节点号的数目
	uint8_t climited = 5;    //收到的包数大于10才进行整理
	uint8_t sendnum = 3;       //发送次数
	uint8_t prin = 0;          
	message_t pkt;
	message_t pkt2;
	bool busy = FALSE;
	bool over = FALSE;
	bool initmxmi = FALSE;     
	bool changed = FALSE;
	uint16_t i;
	uint16_t j;
	uint16_t k;
	
	uint8_t u_node_id[30];  //存放要打印的新收到的节点号
	uint8_t u_array_node = 0;   //存放进上面数组的指针
	uint8_t ul_node_id[30];     //存放要打印的重复的节点号
	uint8_t ul_array_node = 0;   //存放进上面数组的指针
	uint8_t u_array_out_index = 0;   //要打印的新收到的节点号的出的指针
	uint8_t ul_array_out_index = 0;  //要打印的没用的节点号的出的指针
 
	bool pr_flag1 = FALSE;     
	bool pr_flag2 = FALSE;
	bool pr_flag3 = FALSE;
	bool pr_flag4 = FALSE;
	bool pr_flag6 = FALSE;
	bool pr_flag7 = FALSE;
	bool pr_flag8 = FALSE;
	
	bool max_flag = FALSE;
	bool min_flag = FALSE;
	
	bool judge_send = FALSE;
	

	task void print()
	{
		uint8_t i;
		if(pr_flag1) 
		{
			unit_8 i2;
			printf("brocasting my node id as %d\n",TOS_NODE_ID);
			printf("\nmax: ");
			for(i2=0;i2<10;i2++){
				printf(" %d ",max[i2]);
			}
			printf("\nmin: ");
			for(i2=0;i2<10;i2++){
				printf(" %d ",min[i2]);
			}
			printfflush();
			pr_flag1 = FALSE;
		}
		else if(pr_flag2) 
		{
			printf("sending max.\n");printfflush();
			pr_flag2 = FALSE;
		}
		else if(pr_flag3) 
		{
			printf("sending min.\n");
			printfflush();
			pr_flag3 = FALSE;
		}
		else if(pr_flag4) 
		{
			printf("I have received mxmi.\n");
			printfflush();
			pr_flag4 = FALSE;
		}
		else if(pr_flag6) 
		{
			printf("receive:%d\n",u_node_id[u_array_out_index]);
			u_array_out_index = (u_array_out_index+1)%30;
			printfflush();
			pr_flag6 = FALSE;
		}
		else if(pr_flag7) 
		{
			for(i=0;i<10;i++)
			{
				printf("max:%d\n",max[i]);
				printfflush();
			}
			pr_flag7 = FALSE;
		}
		else if(pr_flag8) 
		{
			for(i=0;i<10;i++)
			{
				printf("min:%d\n",min[i]);
				printfflush();
			}
			pr_flag8 = FALSE;
		}
	}

	event void Boot.booted() {
		call Leds.led0On();
		call AMControl.start();
		if(TOS_NODE_ID!=0&&TOS_NODE_ID!=1){data[0] = TOS_NODE_ID;}

		for(i=0;i<=9;i++)
		{
			min[i] = 255;
			max[i] = 0;
		}
	}

	event void AMControl.startDone(error_t err) {
		if (err == TRUE)
		{ call AMControl.start(); }
		else {
			if(TOS_NODE_ID!=0&&TOS_NODE_ID!=1) {
				call Timer0.startPeriodic((TOS_NODE_ID%7)*1000+(TOS_NODE_ID%2)*500);   				//发送自己的节点号
				call Timer1.startPeriodic(3155);
			}
		}
	}
	
	task void send_Node_ID(){
		if(judge_send){
			if(!busy) {
			nodeMsg* btrpkt = (nodeMsg*)(call Packet.getPayload(&pkt,sizeof(nodeMsg)));
			if(btrpkt==NULL) { return; }
			btrpkt->node_id = TOS_NODE_ID;
			if (call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(nodeMsg)) == SUCCESS){ 
                                busy = TRUE;
				}
				pr_flag1 = TRUE;
				post print();
			}
			judge_send = FALSE;
		}
	}

	event void Timer0.fired() {
		if(sendnum>0){
			judge_send = TRUE;
			sendnum = sendnum-1;
			post send_Node_ID();
		}	
	}
	
	event void Timer1.fired() {
        uint8_t i2 =0;
		printf("node ID: %d\n",TOS_NODE_ID);
		printf("sendnum: %d\n",sendnum);
		printf("data: ");

		for(i2=0;i2<counter;i2++){
			printf(" %d ",data[i2]);
		}
		printf("\n");
		printfflush();
		printf("counter: %d \n",counter);
		//if(counter>10){
			//printf("\nmax: ");
			//for(i2=0;i2<10;i2++){
				//printf(" %d ",max[i2]);
			//}
			//printf("\nmin: ");
			//for(i2=0;i2<10;i2++){
				//printf(" %d ",min[i2]);
			//}
		//}
	}

	task void sentmax() {     //发送自己整理max数组
		if(max_flag){
			if(!busy) {
				dataMsg* btrpkt2 = (dataMsg*)(call Packet.getPayload(&pkt,sizeof(dataMsg)));
				if(btrpkt2==NULL) { return; }
				for(i=0;i<=9;i++)      //
					btrpkt2->data[i] = max[i];
				btrpkt2->mxmi = TRUE;      
				btrpkt2->renewmxmi = FALSE;
				if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMsg)) == SUCCESS){
					max_flag = FALSE;
					pr_flag2 = TRUE;
					post print();
					climited = climited + 1;
				 }
			}
		}
		
	}

	task void sentmin() {        //发送自己整理min数组
		if(min_flag){
			if(!busy) {
				dataMsg* btrpkt2 = (dataMsg*)(call Packet.getPayload(&pkt2,sizeof(dataMsg)));
				if (btrpkt2 == NULL) {
					return;
				}
				for(i=0;i<=9;i++) {
					btrpkt2->data[i] = min[i];
				}
				btrpkt2->mxmi = FALSE;
				btrpkt2->renewmxmi = FALSE;
				if(call AMSend.send(AM_BROADCAST_ADDR,&pkt2,sizeof(dataMsg)) == SUCCESS){
					min_flag = FALSE;
					pr_flag3 = TRUE;
					post print();	
				 }
			}
		}
				
	}

	event void AMSend.sendDone(message_t* msg, error_t err) {
		if(&pkt == msg) {
			busy = FALSE;
		}
	}

	event void AMControl.stopDone(error_t err) {}

	event message_t* Receive.receive(message_t* msg,void* payload,uint8_t len) {
		uint16_t t;
		uint8_t node_id;
		if(len == sizeof(nodeMsg)) {		//receving the node id from other nodes except 0/1
			bool node_flag = FALSE;
			nodeMsg* btrpkt = (nodeMsg*)payload;
			node_id = btrpkt->node_id;
			for(t= 0;t<counter;t++){      //接收之前收到的包
				if(data[t]==node_id) {
					ul_node_id[ul_array_node] = node_id;
					ul_array_node = (ul_array_node+1)%30;
					return msg;
				}
			}
			for(t=0;t<counter;t++){     //接收的节点号比数组里面值要小
				if(node_id < data[t]){
					for(j=counter;j>t;j--) {
						data[j] = data[j-1]; 
					}
					data[j] = node_id;
					counter = counter+1;
					node_flag = TRUE;
					break;
				}
			}
			if(!node_flag){
				data[counter] = node_id;
				counter = counter+1;
			}
			if(node_flag){
				node_flag = FALSE;
			}
			
			u_node_id[u_array_node] = node_id;
			u_array_node = (u_array_node + 1) % 30;
			
			pr_flag6 = TRUE;
			post print();  //打印收入DATA信息
	    
			if(counter>5) {      //收到了10个节点的节点号
				if(TOS_NODE_ID==0||TOS_NODE_ID==1) {    //如果当前节点是0或者1
						prin++;
						return msg;
				}
				if(initmxmi == FALSE){   //如果没有初始化max和min包
				   for(i = 9; i >= 0; i--){    // max
						max[i] = data[counter-1-i]; //max值从大到小
				    }
					for(i = 0; i <= 9; i++){    // min
						if(TOS_NODE_ID!=0&&TOS_NODE_ID!=1){
								min[i] = data[i];  //min从小到大
						}//if
						else min[i] = data[i+1];
					}//for min
					initmxmi = TRUE;
				}//for init
				else{       //第二次或者第三次发送最大值或者最小值数组
					for(i = 0; i <= 9; i++){    // max
						if(node_id == max[i]) break;      //查看新收到的ID是否已经存在在max数组里面
						else if(node_id > max[i]){
						  for(j = 9; j > i; j--){
						  max[j] = max[j-1];
						  }
						  max[j] = node_id;
						  break;
						} 
					}
					for(i = 0; i <= 9; i++){    // min
						if(node_id == min[i]) break;       //查看新收到的ID是否已经存在在max数组里面
						else if(node_id < min[i]){
						    if(node_id != 0 && node_id != 1){
								for(j = 9; j > i; j--){
									min[j] = min[j-1];
								}
								min[j] = node_id;
							}
						    break;
						}
					}
				}
				post sentmax();				//max
				post sentmin();
			}   //接收到足够的包数才进行初始化最大最小数组
			return msg;
		}
		else if(len == sizeof(dataMsg)) {                    //receive max or min
			dataMsg* btrpkt = (dataMsg*)payload;
			pr_flag4 = TRUE;
			post print();
			if((TOS_NODE_ID==0)&&(btrpkt->renewmxmi)&&(btrpkt->mxmi)) {
				for(i=0,j=0,k=0;i<=9;i++)   //把新收到的最大值数组的包与自己的最大值数组比较，得出比较后的最大值数组
				{
					if(max[j]==btrpkt->data[k])
					{
						middle[i] = max[j];
						j++;
						k++;
					}
					else if(max[j]>btrpkt->data[k])
					{
						middle[i] = max[j];
						j++;
					}
					else {
						middle[i] = btrpkt->data[k];
						k++;
					}
				}
				for(i=0;i<=9;i++)
				{ 
					max[i] = middle[i]; 
				}
				prin++;
				if(prin>4) {
					pr_flag7 = TRUE;
					post print(); 
				}
			}
			if((TOS_NODE_ID==1)&&(btrpkt->renewmxmi)&&(!btrpkt->mxmi)) {//针对0 、1号节点
				for(i=0,j=0,k=0;i<=9;i++)     //把新收到的最小值数组的包与自己的最小值数组比较，得出比较后的最大值数组
				{
					if(min[j]==btrpkt->data[k])
					{
						middle[i] = min[j];
						j++;
						k++;
					}
					else if(min[j]<btrpkt->data[k])
					{
						middle[i] = min[j];
						j++;
					}
					else {
						middle[i] = btrpkt->data[k];
						k++;
					}
				}
				for(i=0;i<=9;i++)
				{ 
					min[i] = middle[i]; 
				}
				prin++;
				if(prin>3) {
					pr_flag8 = TRUE;
					post print();
				}
			}
			if(counter<climited)    //收到的包数没有到门阀值
			{
				if(!initmxmi){      //没有初始化max和min数组的情况
					if(counter>10){//收集数据大于10，maxmin正常初始化
						for(i = 9; i >= 0; i--){    // max
							max[i] = data[counter-1-i]; //max值从大到小
						}
						for(i = 0; i <= 9; i++){    // min
							if(TOS_NODE_ID!=0&&TOS_NODE_ID!=1){
								min[i] = data[i];  //min从小到大
							}//if
							else min[i] = data[i+1];
						}//for min
						initmxmi = TRUE;
					}//if counter>10
					else if(counter=10){//收集数据为10个时maxmin初始化，注意节点号为0/1情况
						for(i = 9; i >= 0; i--){    // max
							max[i] = data[counter-1-i]; //max值从大到小
						}
						if(TOS_NODE_ID!=0&&TOS_NODE_ID!=1){
							for(i = 0; i <= 9; i++){
								min[i] = data[i];  //min从小到大
							}
						}//if
						else{
							for(i = 0; i <= 9; i++){
								min[i] = data[i+1];  //min从小到大
							}
							min[9] = 255;     //当数据只有10个的时候，并且节点号是0或者1，那么有一个是自己的节点号，那么min数组缺少了一个数，先暂时置为255，方便后面更新
						}
						initmxmi = TRUE;
					}//else if counter = 10
					else if(counter<10){//收集数据不足10个时maxmin初始化
						for(i = 9; i > 9-counter; i--){    // max
							max[i] = data[counter-1-i]; //max值从大到小   
						}
						for(i;i>=0;i--){
							max[i] = 0;
						}
						if(TOS_NODE_ID!=0&&TOS_NODE_ID!=1){
							for(i = 0; i <counter; i++){
								min[i] = data[i];  //min从小到大
							}
							for(i;i<=9;i--){
							min[i] = 255;
							}
						}//if
						else{
							for(i = 0; i <counter-1; i++){
								min[i] = data[i+1];  //min从小到大
							}
							for(i;i<=9;i--){
							min[i] = 255;
							}
						}//else TOS_NODE_ID=0/1
						initmxmi = TRUE;
					}//else if counter<10
				}//if !init
				else{          
					if(!btrpkt->mxmi) {		//receive min
						for(i=0,j=0,k=0;i<=9;i++)
						{
							if(min[j]==btrpkt->data[k])
							{
								middle[i] = min[j];
								j++;
								k++;
							}
							else if(min[j]<btrpkt->data[k])
							{
								middle[i] = min[j];
								j++;
							}
							else {
								middle[i] = btrpkt->data[k];
								k++;
							}
						}
					}//if !mxmi
					else if(btrpkt->mxmi){
						for(i=0,j=0,k=0;i<=9;i++)
						{
							if(max[j]==btrpkt->data[k])
							{
								middle[i] = max[j];
								j++;
								k++;
							}
							else if(max[j]>btrpkt->data[k])
							{
								middle[i] = max[j];
								j++;
							}
							else {
								middle[i] = btrpkt->data[k];
								k++;
							}
						}
					}//else if mxmi
				}
			}
			else if(counter>=climited) {//compare and give away the better,else do nothing
				if(!btrpkt->mxmi) {		//receive min
					for(i=0,j=0,k=0;i<=9;i++)
					{
						if(min[j]==btrpkt->data[k])
						{
							middle[i] = min[j];
							j++;
							k++;
						}
						else if(min[j]<btrpkt->data[k])
						{
							middle[i] = min[j];
							j++;
						}
						else {
							middle[i] = btrpkt->data[k];
							k++;
						}
					}
					if(j != 10) {//包对我的min有更新
						for(i=0;i<=9;i++)
							min[i] = middle[i];
						if(!busy) {
							dataMsg* btrpkt2 = (dataMsg*)(call Packet.getPayload(&pkt,sizeof(dataMsg)));
							if(btrpkt2 == NULL) { return; }
							for(i=0;i<=9;i++)
								btrpkt2->data[i] = min[i];
							btrpkt2->mxmi = FALSE;
							btrpkt2->renewmxmi = TRUE;
							if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMsg)) == SUCCESS)
								busy = TRUE;
						}
					}
				}
				else {						//receive max
					for(i=0,j=0,k=0;i<=9;i++)
					{
						if(max[j]==btrpkt->data[k])
						{
							middle[i] = max[j];
							j++;
							k++;
						}
						else if(max[j]>btrpkt->data[k])
						{
							middle[i] = max[j];
							j++;
						}
						else {
							middle[i] = btrpkt->data[k];
							k++;
						}
					}
					if(j != 10) {
						for(i=0;i<=9;i++)
							max[i] = middle[i];
						if(!busy) {
							dataMsg* btrpkt2 = (dataMsg*)(call Packet.getPayload(&pkt,sizeof(dataMsg)));
							if(btrpkt2 == NULL) { return; }
							for(i=0;i<=9;i++)
								btrpkt2->data[i] = max[i];
							btrpkt2->mxmi = TRUE;
							btrpkt2->renewmxmi = TRUE;
							if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMsg)) == SUCCESS)
								busy = TRUE;
						}
					}
				}
			}
			else {							//don't have enough id
				if((btrpkt->renewmxmi)&&(!over))		//transfer
				{
					if (call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMsg)) == SUCCESS) { busy = TRUE; }
					over = TRUE;
				}
			}
		return msg;
		}
		else{
			return msg;
		}
	}
}
